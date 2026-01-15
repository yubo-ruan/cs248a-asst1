from dataclasses import dataclass
from abc import ABC

from pyglm import glm


@dataclass
class BoundingBox3D:
    """A 3D axis-aligned bounding box defined by minimum and maximum corners.

    :param min: Minimum corner of the bounding box.
    :param max: Maximum corner of the bounding box.
    """

    min: glm.vec3
    max: glm.vec3


class BoundingBoxObject(ABC):
    """An abstract base class for objects that have a bounding box."""

    @property
    def bounding_box(self) -> BoundingBox3D:
        """Returns the axis-aligned bounding box of the object."""
        raise NotImplementedError
