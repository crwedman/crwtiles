from __future__ import annotations
from enum import IntEnum
from mathutils import Vector
from math import atan2, pi

class Orientation(IntEnum):
    ANY = -1
    E = 0
    NE = 1
    N = 2
    NW = 3
    W = 4
    SW = 5
    S = 6
    SE = 7

    @classmethod
    def flip(cls, value: Orientation) -> Orientation:
        if value in {cls.NE, cls.NW}:
            return cls.NE if cls.NW == value else cls.NW
        if value in {cls.E, cls.W}:
            return cls.E if cls.W == value else cls.W
        if value in {cls.SE, cls.SW}:
            return cls.SE if cls.SW == value else cls.SW
        return value

    @classmethod
    def snap(cls, vector: Vector) -> Orientation:
        """
        Calculate orientation index from a 2D vector.
        Maps orientation to 0-7 (E, NE, N, etc.) with wrapping for negatives, else returns -1 (ANY)
        """
        if (vector.length < 1e-6):
            return cls.ANY
        angle = atan2(vector.y, vector.x)  # Range: -π to π
        index = int(round(angle * 4 / pi))  # Scale to 8 orientations
        return Orientation(index % 8)  # Wrap negatives to [0, 7]

