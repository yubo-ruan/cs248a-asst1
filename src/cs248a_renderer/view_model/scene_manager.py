"""
Scene manager for volumetric rendering application.
"""

import logging
from pathlib import Path
from typing import List, Tuple
import numpy as np
from pyglm import glm
import slangpy as spy
import open3d as o3d

from cs248a_renderer.model.cameras import PerspectiveCamera
from cs248a_renderer.model.scene import Scene
from cs248a_renderer.model.transforms import Transform3D
from cs248a_renderer.model.scene_object import get_next_scene_object_index
from cs248a_renderer.model.mesh import Mesh


logger = logging.getLogger(__name__)


DEFAULT_CAM_TRANSFORM = Transform3D(
    position=glm.vec3(0.0, 0.0, 2.5),
    rotation=glm.quat(1.0, 0.0, 0.0, 0.0),
    scale=glm.vec3(1.0, 1.0, 1.0),
)


class SceneManager:
    scene: Scene

    def __init__(self):
        self.scene = Scene()

    def load_mesh(self, mesh_path: Path, name: str | None = None) -> None:
        """
        Load a mesh from the given path and add it to the scene root.

        :param mesh_path: Path to the mesh file.
        :type mesh_path: Path
        :param name: Name of the mesh object. If None, a default name will be assigned.
        :type name: str | None
        """
        logger.info(f"Loading mesh from {mesh_path}")
        o3d_mesh = o3d.io.read_triangle_mesh(str(mesh_path))
        if name is None:
            name = f"mesh_{get_next_scene_object_index()}"
        mesh = Mesh(o3d_mesh=o3d_mesh, name=name)
        self.scene.add_object(mesh)
        logger.info(f"Added mesh '{mesh.name}' to scene")
