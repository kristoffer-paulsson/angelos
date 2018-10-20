import math
import enum


class Eidon:
    "εἶδον - Eidon"
    SIZES = (0, 1, 1, 3, 3, 4, 4)
    QUALITY = (0, 3, 6, 10, 15)
    EMPTY = [[[0. for _ in range(8)] for _ in range(8)] for _ in range(3)]
    PI_D_16 = math.pi / 16.0
    ONE_D_SQRT2 = 1.0 / math.sqrt(2.0)

    class Quality(enum.IntEnum):
        BAD = 1
        GOOD = 2
        BETTER = 3
        BEST = 4

    class Format(enum.IntEnum):
        NONE = 0
        INDEX = 1
        GRAYSCALE = 2
        RGB = 3
        YCBCR = 4
        RGBA = 5
        YCBCRA = 6
