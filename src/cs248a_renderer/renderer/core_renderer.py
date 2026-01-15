"""
Core rendering module
"""

import slangpy as spy
from typing import Tuple
from pyglm import glm
import numpy as np
from reactivex.subject import BehaviorSubject

from cs248a_renderer import RendererModules
from cs248a_renderer.model.scene import Scene
from cs248a_renderer.model.mesh import create_triangle_buf


class Renderer:
    _device: spy.Device
    _render_target: spy.Texture

    # Primitive buffers.
    _triangle_buf: spy.NDBuffer | None
    _triangle_count: int | None

    def __init__(
        self,
        device: spy.Device,
        render_texture_sbj: BehaviorSubject[Tuple[spy.Texture, int]] | None = None,
        render_texture: spy.Texture | None = None,
    ) -> None:
        self._device = device

        def update_render_target(texture: Tuple[spy.Texture, int]):
            self._render_target = texture[0]

        if render_texture is not None:
            self._render_target = render_texture
        elif render_texture_sbj is not None:
            render_texture_sbj.subscribe(update_render_target)
        else:
            raise ValueError(
                "Must provide a render_texture or render_texture_sbj for VolumeRenderer."
            )

        # Load renderer module.
        render_modules = RendererModules(device=device)
        self.primitive_module = render_modules.primitive_module
        self.renderer_module = render_modules.renderer_module

    def load_scene(self, scene: Scene) -> None:
        """Load a scene into the renderer."""
        triangles = scene.extract_triangles()
        if len(triangles) > 0:
            self._triangle_buf = create_triangle_buf(self.primitive_module, triangles)
        self._triangle_count = len(triangles)

    def render(self, view_mat: glm.mat4, fov: float):
        """Render the loaded scene."""
        if self._triangle_count == 0:
            return
        focal_length = (0.5 * float(self._render_target.height)) / np.tan(
            np.radians(fov) / 2.0
        )
        self.renderer_module.render(
            tid=spy.grid(shape=(self._render_target.height, self._render_target.width)),
            uniforms={
                "camera": {
                    "invViewMatrix": np.ascontiguousarray(
                        glm.inverse(view_mat), dtype=np.float32
                    ),
                    "canvasSize": [
                        self._render_target.width,
                        self._render_target.height,
                    ],
                    "focalLength": float(focal_length),
                },
                "ambientColor": [0.0, 0.0, 0.0, 1.0],
                "sqrtSpp": 4,
                "triangleBuf": self._triangle_buf,
                "triangleCount": self._triangle_count,
            },
            _result=self._render_target,
        )
