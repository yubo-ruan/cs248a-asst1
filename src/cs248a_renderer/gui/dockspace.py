"""
Volumetric renderer dockspace.
"""

from typing import TypedDict, Unpack
from imgui_bundle import imgui
from reactivex.subject import BehaviorSubject, Subject
from slangpy_imgui_bundle.render_targets.dockspace import Dockspace, DockspaceArgs
from slangpy_imgui_bundle.render_targets.menu import Menu, MenuItem, SimpleMenuItem
from slangpy_imgui_bundle.utils.fps_counter import FPSCounter


class FileSubjects(TypedDict):
    on_load_mesh: Subject[None]


class WindowOpenSubjects(TypedDict):
    scene_wizard_open: Subject[None]
    preview_open: BehaviorSubject[bool]
    renderer_open: BehaviorSubject[bool]
    scene_editor_open: BehaviorSubject[bool]


class VolumetricDockspaceArgs(DockspaceArgs):
    file_subjects: FileSubjects
    window_open_subjects: WindowOpenSubjects
    render_request: Subject[None]


class VolumetricDockspace(Dockspace):
    def __init__(self, **kwargs: Unpack[VolumetricDockspaceArgs]) -> None:
        super().__init__(**kwargs)

        self._menu_items = [
            Menu(
                device=self._device,
                adapter=self._adapter,
                name="File",
                children=[
                    Menu(
                        device=self._device,
                        adapter=self._adapter,
                        name="Load",
                        children=[
                            SimpleMenuItem(
                                device=self._device,
                                adapter=self._adapter,
                                name="Mesh",
                                on_clicked=lambda: kwargs["file_subjects"][
                                    "on_load_mesh"
                                ].on_next(None),
                            ),
                        ],
                    ),
                ],
            ),
            Menu(
                device=self._device,
                adapter=self._adapter,
                name="Views",
                children=[
                    MenuItem(
                        device=self._device,
                        adapter=self._adapter,
                        name="Preview",
                        open=kwargs["window_open_subjects"]["preview_open"],
                        on_open_changed=lambda opened: kwargs["window_open_subjects"][
                            "preview_open"
                        ].on_next(opened),
                    ),
                    MenuItem(
                        device=self._device,
                        adapter=self._adapter,
                        name="Renderer",
                        open=kwargs["window_open_subjects"]["renderer_open"],
                        on_open_changed=lambda opened: kwargs["window_open_subjects"][
                            "renderer_open"
                        ].on_next(opened),
                    ),
                    MenuItem(
                        device=self._device,
                        adapter=self._adapter,
                        name="Scene Editor",
                        open=kwargs["window_open_subjects"]["scene_editor_open"],
                        on_open_changed=lambda opened: kwargs["window_open_subjects"][
                            "scene_editor_open"
                        ].on_next(opened),
                    ),
                ],
            ),
            Menu(
                device=self._device,
                adapter=self._adapter,
                name="Renderer",
                children=[
                    SimpleMenuItem(
                        device=self._device,
                        adapter=self._adapter,
                        name="Render",
                        on_clicked=lambda: kwargs["render_request"].on_next(None),
                    ),
                ],
            ),
        ]

        self._status_items = [FPSCounter()]

    def build(self, dockspace_id: int) -> None:
        # Build dock space.
        if not imgui.internal.dock_builder_get_node(dockspace_id):
            imgui.internal.dock_builder_remove_node(dockspace_id)
            main_id = imgui.internal.dock_builder_add_node(dockspace_id)
            # Split the main node into view node, and property node.
            res = imgui.internal.dock_builder_split_node(main_id, imgui.Dir.left, 0.7)
            view_id = res.id_at_dir
            property_id = res.id_at_opposite_dir
            # Split the property node into scene editor and camera controls.
            res = imgui.internal.dock_builder_split_node(property_id, imgui.Dir.up, 0.8)
            scene_editor_id = res.id_at_dir
            camera_controls_id = res.id_at_opposite_dir

            imgui.internal.dock_builder_dock_window("Preview", view_id)
            imgui.internal.dock_builder_dock_window("Renderer", view_id)

            imgui.internal.dock_builder_dock_window("Scene Editor", scene_editor_id)
            imgui.internal.dock_builder_dock_window(
                "Camera Controls", camera_controls_id
            )

            imgui.internal.dock_builder_finish(dockspace_id)
