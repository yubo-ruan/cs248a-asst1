"""
Volumetric renderer application.
"""

import asyncio
from pathlib import Path
import logging
from typing import Tuple
import platform
from imgui_bundle import imgui_tex_inspect, portable_file_dialogs as pfd
from reactivex.subject import BehaviorSubject, Subject
from slangpy_imgui_bundle.app import App
import slangpy as spy
from slangpy_nn.utils import slang_include_paths
from slangpy_imgui_bundle.utils.file_dialog import async_file_dialog

from cs248a_renderer import SHADER_PATH
from cs248a_renderer.gui.dockspace import VolumetricDockspace
from cs248a_renderer.gui.preview import PreviewWindow
from cs248a_renderer.gui.renderer import RendererWindow
from cs248a_renderer.gui.scene_editor import SceneEditorWindow
from cs248a_renderer.model.scene_object import SceneObject
from cs248a_renderer.view_model.scene_manager import SceneManager

# from cs248a_renderer.renderer.volume_renderer import VolumeRenderer
# from cs248a_renderer.renderer.nerf_renderer import NeRFRenderer
from cs248a_renderer.renderer.core_renderer import Renderer


logger = logging.getLogger(__name__)


FONT_PATH = Path(__file__).parent / "fonts" / "JetBrainsMonoNerdFontMono-Regular.ttf"
_system = platform.system()
if _system == "Darwin":
    DEVICE_TYPE = spy.DeviceType.metal
elif _system in ("Windows", "Linux"):
    DEVICE_TYPE = spy.DeviceType.vulkan
else:
    # Default to vulkan for unknown/other platforms
    DEVICE_TYPE = spy.DeviceType.vulkan


class InteractiveRendererApp(App):
    window_title = "CS 248A Interactive Renderer"
    fb_scale = 1.0
    font_size = 16
    device_type = DEVICE_TYPE

    scene_manager: SceneManager = SceneManager()
    core_renderer: Renderer
    # volume_renderer: VolumeRenderer
    # nerf_renderer: NeRFRenderer
    render_texture: BehaviorSubject[Tuple[spy.Texture, int]]
    canvas_size: BehaviorSubject[Tuple[int, int]] = BehaviorSubject((800, 600))
    render_request: Subject[None] = Subject()
    editing_object: BehaviorSubject[SceneObject | None] = BehaviorSubject(None)

    _scene_wizard_open: Subject[None] = Subject()
    _preview_open: BehaviorSubject[bool] = BehaviorSubject(True)
    _renderer_open: BehaviorSubject[bool] = BehaviorSubject(True)
    _scene_editor_open: BehaviorSubject[bool] = BehaviorSubject(True)

    _on_load_mesh: Subject[None] = Subject()

    def __init__(self) -> None:
        shader_paths = [SHADER_PATH]
        shader_paths.extend(slang_include_paths())
        super().__init__(user_shader_paths=shader_paths)

        imgui_tex_inspect.init()
        imgui_tex_inspect.create_context()

        self._reload_font(self.font_size)

        self._on_load_mesh.subscribe(lambda _: asyncio.create_task(self._load_mesh()))

        # --------------------- Volume Renderer  --------------------- #

        texture = self._create_render_texture(
            self.canvas_size.value[0], self.canvas_size.value[1]
        )
        texture_id = self.adapter.register_texture(texture)
        self.render_texture = BehaviorSubject((texture, texture_id))
        self.core_renderer = Renderer(
            device=self.device, render_texture_sbj=self.render_texture
        )

        self.canvas_size.subscribe(self._on_canvas_resize)
        self.render_request.subscribe(self._on_render_request)

        # --------------------------- GUI  --------------------------- #

        self._dockspace = VolumetricDockspace(
            device=self.device,
            adapter=self.adapter,
            window_size=self._curr_window_size,
            window_open_subjects={
                "preview_open": self._preview_open,
                "scene_wizard_open": self._scene_wizard_open,
                "renderer_open": self._renderer_open,
                "scene_editor_open": self._scene_editor_open,
            },
            file_subjects={
                "on_load_mesh": self._on_load_mesh,
            },
            render_request=self.render_request,
        )

        self._render_targets = [
            PreviewWindow(
                device=self.device,
                adapter=self.adapter,
                open=self._preview_open,
                on_close=lambda: self._preview_open.on_next(False),
                scene_manager=self.scene_manager,
                canvas_size=self.canvas_size,
                editing_object=self.editing_object,
            ),
            RendererWindow(
                device=self.device,
                adapter=self.adapter,
                open=self._renderer_open,
                on_close=lambda: self._renderer_open.on_next(False),
                render_texture=self.render_texture,
                render_request=self.render_request,
            ),
            SceneEditorWindow(
                device=self.device,
                adapter=self.adapter,
                open=self._scene_editor_open,
                on_close=lambda: self._scene_editor_open.on_next(False),
                scene_manager=self.scene_manager,
                editing_object=self.editing_object,
            ),
        ]

    def _on_canvas_resize(self, size: tuple[int, int]) -> None:
        width, height = size
        curr_id = self.render_texture.value[1]
        self.adapter.unregister_texture(curr_id)
        texture = self._create_render_texture(width, height)
        texture_id = self.adapter.register_texture(texture)
        self.render_texture.on_next((texture, texture_id))

    def _on_render_request(self, _) -> None:
        # if self.scene_manager.volume_scene is not None:
        #     self.volume_renderer.render(
        #         scene=self.scene_manager.volume_scene,
        #         view_mat=self.scene_manager.volume_scene.camera.view_matrix(),
        #         fov=self.scene_manager.volume_scene.camera.fov,
        #         use_albedo_volume=self.scene_manager.volume_scene.volume.channels == 4,
        #     )
        # elif self.scene_manager.nerf_scene is not None:
        #     self.nerf_renderer.render(
        #         scene=self.scene_manager.nerf_scene,
        #         view_mat=self.scene_manager.nerf_scene.camera.view_matrix(),
        #         fov=self.scene_manager.nerf_scene.camera.fov,
        #     )
        self.core_renderer.load_scene(self.scene_manager.scene)
        self.core_renderer.render(
            view_mat=self.scene_manager.scene.camera.view_matrix(),
            fov=self.scene_manager.scene.camera.fov,
        )

    def _reload_font(self, size: int) -> None:
        self.io.fonts.clear()
        self.io.fonts.add_font_from_file_ttf(
            str(FONT_PATH),
            size * self.fb_scale,
        )
        self.adapter.refresh_font_texture()
        self.io.font_global_scale = 1.0 / self.fb_scale

    def _create_render_texture(self, width: int, height: int) -> spy.Texture:
        return self.device.create_texture(
            type=spy.TextureType.texture_2d,
            width=width,
            height=height,
            format=spy.Format.rgba8_unorm,
            usage=spy.TextureUsage.unordered_access | spy.TextureUsage.shader_resource,
        )

    async def _load_mesh(self) -> None:
        mesh_path = await self._choose_file(filters=["Obj Files", "*.obj"])
        if mesh_path is not None:
            self.scene_manager.load_mesh(mesh_path=mesh_path)

    async def _choose_file(self, filters: list[str] = []) -> Path | None:
        files = await async_file_dialog(
            title="Open File",
            default_path=str(Path.cwd()),
            filters=filters,
            options=pfd.opt.none,
        )
        if files:
            file_path = Path(files[0])
            logger.info("Selected file: %s", file_path)
            return file_path
        return None
