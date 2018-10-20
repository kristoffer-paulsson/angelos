import math
import asyncio

from .eidon import Eidon
from .image import EidonImage
from .stream import EidonStream, StreamRGB
from .palettes import Palette
from .matrix import Matrix


class EidonEncoder:
    def __init__(self, image, stream):
        if not isinstance(image, EidonImage): raise TypeError()  # noqa E701
        if not isinstance(stream, EidonStream): raise TypeError()  # noqa E701

        self._image = image
        self._stream = stream
        self._m_width = int(math.floor(image.width / 8))
        self._m_height = int(math.floor(image.height / 8))
        self._dither = []
        self._palette = [
            Palette.RGB676,
            Palette.RGB676
        ] if isinstance(stream, StreamRGB) else [
            Palette.YCBCR766RGB,
            Palette.YCBCR766
        ]
        self._factor = [
            Matrix.QUANTITY_Y,
            Matrix.QUANTITY_Y,
            Matrix.QUANTITY_Y
        ] if isinstance(stream, StreamRGB) else [
            Matrix.QUANTITY_Y,
            Matrix.QUANTITY_C,
            Matrix.QUANTITY_C
        ]
        stream.clear()

    def run(self, _async=False):
        size = self._stream.size()
        for iteration in range(self._m_height):
            lines = self.dither(iteration * 8, 8)

            for block in range(self._m_width):
                matrix = self.get_matrix(lines, 0, block * 8)

                for d in range(size):
                    transform = self.dct(matrix[d])
                    quantity = self.quantize(
                        transform, self._factor[d])
                    entropy = self.entropize(quantity)
                    self._stream.pack(entropy)

            if _async:
                asyncio.sleep(.1)

        return self._stream

    def dither(self, offset=0, rows=0):
        lines = []

        for y in range(
                offset, self._image.height if not rows else min(
                    offset + rows, self._image.height)):
            line = bytearray(b'\x00' * self._m_width*8)

            for x in range(self._image.width):
                old_p = self._image.get(x, y)  # Get current pixel
                (new_i, new_p) = min(
                    enumerate(self._palette[0]), key=lambda x: (
                        self.distance(x[1], old_p), x))
                self._image.set(x, y, new_p)  # Write new RGB to input image
                line[x] = new_i

                # Calculating the color difference
                re = old_p[0] - new_p[0]
                ge = old_p[1] - new_p[1]
                be = old_p[2] - new_p[2]

                # Pushing 7/16 of difference right
                if x < self._image.width - 1:
                    nei_p = self._image.get(x+1, y)
                    nei_p[0] += round(re * 7/16)
                    nei_p[1] += round(ge * 7/16)
                    nei_p[2] += round(be * 7/16)
                    self._image.set(x+1, y, nei_p)

                # Pushing 3/16 of difference left down
                if x > 1 and y < self._image.height - 1:
                    nei_p = self._image.get(x-1, y+1)
                    nei_p[0] += round(re * 3/16)
                    nei_p[1] += round(ge * 3/16)
                    nei_p[2] += round(be * 3/16)
                    self._image.set(x-1, y+1, nei_p)

                # Pushing 5/16 of difference down
                if y < self._image.height - 1:
                    nei_p = self._image.get(x, y+1)
                    nei_p[0] += round(re * 5/16)
                    nei_p[1] += round(ge * 5/16)
                    nei_p[2] += round(be * 5/16)
                    self._image.set(x, y+1, nei_p)

                # Pushing 1/16 of difference left down
                if x < self._image.width - 1 and y < self._image.height - 1:
                    nei_p = self._image.get(x+1, y+1)
                    nei_p[0] += round(re * 1/16)
                    nei_p[1] += round(ge * 1/16)
                    nei_p[2] += round(be * 1/16)
                    self._image.set(x+1, y+1, nei_p)

            lines.append(line)
        return lines

    def distance(self, p1, p2):
        return math.sqrt((p2[0]-p1[0])**2+(p2[1]-p1[1])**2+(p2[2]-p1[2])**2)

    def get_matrix(self, lines, y_pos, x_pos):
        matrix = [[[0. for _ in range(8)] for _ in range(8)] for _ in range(3)]
        for y in range(8):
            for x in range(8):
                pixel = self._palette[1][lines[y_pos+y][x_pos+x]]
                matrix[0][y][x] = pixel[0]
                matrix[1][y][x] = pixel[1]
                matrix[2][y][x] = pixel[2]
        return matrix

    def dct(self, matrix):
        data = [[0. for _ in range(8)] for _ in range(8)]

        for v in range(8):
            for u in range(8):
                z = 0.0
                c_u = Eidon.ONE_D_SQRT2 if not bool(u) else 1.0
                c_v = Eidon.ONE_D_SQRT2 if not bool(v) else 1.0

                for y in range(8):
                    for x in range(8):
                        s = matrix[y][x] - 128
                        q = s * math.cos(
                            (2.*x+1.) * u * Eidon.PI_D_16) * math.cos(
                                (2.*y+1.) * v * Eidon.PI_D_16)
                        z += q
                data[v][u] = .25 * c_u * c_v * z
        return data

    def quantize(self, matrix, factor):
        for y in range(8):
            for x in range(8):
                matrix[y][x] = round(matrix[y][x] / factor[y][x])
        return matrix

    def entropize(self, matrix):
        d = range(self._stream._quality)
        line = list(d)
        p = Matrix.ZIGZAG
        for i in d:
            line[i] = int(matrix[p[i][1]][p[i][0]] + 128)
        return line


class EidonDecoder:
    def __init__(self, stream, image):
        if not isinstance(stream, EidonStream): raise TypeError()  # noqa E701
        if not isinstance(image, EidonImage): raise TypeError()  # noqa E701

        self._stream = stream
        self._image = image
        self._m_width = int(math.floor(image.width / 8))
        self._m_height = int(math.floor(image.height / 8))
        self._factor = [
            Matrix.QUANTITY_Y,
            Matrix.QUANTITY_Y,
            Matrix.QUANTITY_Y
        ] if isinstance(stream, StreamRGB) else [
            Matrix.QUANTITY_Y,
            Matrix.QUANTITY_C,
            Matrix.QUANTITY_C
        ]

        self._converter = self.none2none if isinstance(
            stream, StreamRGB) else self.ycbcr2rgb

        stream.clear()

    def run(self, _async=False):
        size = self._stream.size()
        for y_block in range(self._m_height):
            for x_block in range(self._m_width):

                matrix = list(range(size))
                for c in range(size):
                    entropy = self.deentropize(self._stream.unpack())
                    quantity = self.dequantize(entropy, self._factor[c])
                    matrix[c] = self.idct(quantity)
                self.set_matrix(matrix, y_block*8, x_block*8)

            if _async:
                asyncio.sleep(.1)
        return self._image

    def none2none(self, w):
        return w

    def ycbcr2rgb(self, c):
        return (
            min(max(0, round(c[0] + 1.402 * (c[2] - 128))), 255),
            min(max(0, round(c[0] - (0.114 * 1.772 * (c[1] - 128) + 0.299 * 1.402 * (c[2] - 128)) / 0.587)), 255),  # noqa E501
            min(max(0, round(c[0] + 1.772 * (c[1] - 128))), 255)
        )

    def deentropize(self, line):
        m = [[0. for _ in range(8)] for _ in range(8)]
        p = Matrix.ZIGZAG
        for i in range(self._stream._quality):
            m[p[i][1]][p[i][0]] = line[i] - 128
        return m

    def dequantize(self, matrix, factor):
        for y in range(8):
            for x in range(8):
                matrix[y][x] = round(matrix[y][x] * factor[y][x])
        return matrix

    def idct(self, matrix):
        data = [[0. for _ in range(8)] for _ in range(8)]

        for y in range(8):
            for x in range(8):
                z = 0.0

                for v in range(8):
                    for u in range(8):
                        c_u = Eidon.ONE_D_SQRT2 if not bool(u) else 1.0
                        c_v = Eidon.ONE_D_SQRT2 if not bool(v) else 1.0
                        s = matrix[v][u]

                        q = c_u * c_v * s * math.cos(
                            (2.*x+1) * u * Eidon.PI_D_16) * math.cos(
                                (2.*y+1) * v * Eidon.PI_D_16)
                        z += q

                z = min(max(0, z*.25 + 128), 255)
                data[y][x] = int(z)
        return data

    def set_matrix(self, matrix, y_pos, x_pos):
        for y in range(8):
            for x in range(8):
                self._image.set(
                    x_pos + x, y_pos + y,
                    self._converter((
                        matrix[0][y][x],
                        matrix[1][y][x],
                        matrix[2][y][x]
                    ))
                )
