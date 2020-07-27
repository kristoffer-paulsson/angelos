"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import math
import operator
import types
import enum
import bz2

zig = (
    ( 0,  1,  5,  6, 14, 15, 27, 28),  # noqa E201
    ( 2,  4,  7, 13, 16, 26, 29, 42),  # noqa E201
    ( 3,  8, 12, 17, 25, 30, 41, 43),  # noqa E201
    ( 9, 11, 18, 24, 31, 40, 44, 53),  # noqa E201
    (10, 19, 23, 32, 39, 45, 52, 54),
    (20, 22, 33, 38, 46, 51, 55, 60),
    (21, 34, 37, 47, 50, 56, 59, 61),
    (35, 36, 48, 49, 57, 58, 62, 63)
)


class EidonFile(types.SimpleNamespace):
    pass


class Eidon:
    "εἶδον - Eidon"
    SIZES = (0, 1, 1, 3, 3, 4, 4)
    QUALITY = (0, 3, 6, 10, 15)
    EMPTY = [[[0. for _ in range(8)] for _ in range(8)] for _ in range(3)]
    PI_D_16 = math.pi / 16.0
    ONE_D_SQRT2 = 1.0 / math.sqrt(2.0)
    LOG_NORM = math.pow(2, 8) / math.log(math.pow(2, 10))

    @staticmethod
    def encode(image, meta):
        # Hardcoded: Quality BEST, Signal COMPONENT, Input RGB/RGBA
        q_size = Eidon.QUALITY[Eidon.Quality.BEST]
        m_width = int(math.floor(image.width / 8))
        m_height = int(math.floor(image.height / 8))
        stream = bytearray(b'\xff' * m_width * m_height * q_size)
        stream_cnt = 0
        q_factor = [
            Eidon.Matrix.QUANTITY_Y,
            Eidon.Matrix.QUANTITY_C,
            Eidon.Matrix.QUANTITY_C
        ]

        for iteration in range(m_height):
            lines = Eidon.dither(
                image, Eidon.Palette.YCBCR766RGB, iteration * 8, 8)
            print('Iteration: {} of {}'.format(iteration, m_height))

            for block in range(m_width):
                matrix = Eidon.get_matrix(
                    lines, Eidon.Palette.YCBCR766, 0, block * 8)

                streamed = []
                for dimension in range(3):
                    md = Eidon.dct(matrix[dimension])
                    md = Eidon.quantize(md, q_factor[dimension])
                    streamed.append(Eidon.entropize(md, q_size))

                composite = Eidon.compose(
                    streamed, q_size, Eidon.Palette.YCBCR766)
                stream_cnt = Eidon.pack_stream(
                    stream, stream_cnt, composite)

        return bz2.compress(stream)

    @staticmethod
    def decode(stream, width, height):
        # Hardcoded: Quality BEST, Signal COMPONENT, Output RGB
        q_size = Eidon.QUALITY[Eidon.Quality.BEST]
        m_width = int(math.floor(width / 8))
        m_height = int(math.floor(height / 8))
        image = Eidon.Image(Eidon.Format.RGB, width, height)
        converter = Eidon.Lambda.ycbcr2rgb()
        stream = bz2.decompress(stream)
        stream_cnt = 0
        q_factor = [
            Eidon.Matrix.QUANTITY_Y,
            Eidon.Matrix.QUANTITY_C,
            Eidon.Matrix.QUANTITY_C
        ]

        for y_block in range(m_height):
            print('Block Y: {} of {}'.format(y_block, m_height))

            for x_block in range(m_width):
                offset = stream_cnt * q_size
                components = Eidon.decompose(
                    stream[offset:offset+q_size], q_size,
                    Eidon.Palette.YCBCR766)
                stream_cnt += 1

                matrix = list(range(3))
                for c_block in range(3):
                    block = Eidon.deentropize(components[c_block])
                    Eidon.dequantize(block, q_factor[c_block])
                    matrix[c_block] = Eidon.idct(block)

                Eidon.set_matrix(
                    image, matrix,
                    y_block*8, x_block*8,
                    converter
                )
        return image

    @staticmethod
    def dither(image, palette=None, offset=0, rows=0):
        width = image.width
        height = image.height
        dist = Eidon.Lambda.distance()
        if not bool(palette):
            palette = Eidon.Palette.RGB676
        lines = []

        for y in range(
                offset, height if not rows else min(
                    offset + rows, height)):
            line = bytearray(b'\x00' * image.width)

            for x in range(width):
                old_p = image.get(x, y)  # Get current pixel
                (new_i, new_p) = min(
                    enumerate(palette), key=lambda x: (
                        dist(x[1], old_p), x))  # Find closest, get index
                image.set(x, y, new_p)  # Write new RGB to input image
                line[x] = new_i

                # Calculating the color difference
                re = old_p[0] - new_p[0]
                ge = old_p[1] - new_p[1]
                be = old_p[2] - new_p[2]

                # Pushing 7/16 of difference right
                if x < width - 1:
                    nei_p = image.get(x+1, y)
                    nei_p[0] += round(re * 7/16)
                    nei_p[1] += round(ge * 7/16)
                    nei_p[2] += round(be * 7/16)
                    image.set(x+1, y, nei_p)

                # Pushing 3/16 of difference left down
                if x > 1 and y < height - 1:
                    nei_p = image.get(x-1, y+1)
                    nei_p[0] += round(re * 3/16)
                    nei_p[1] += round(ge * 3/16)
                    nei_p[2] += round(be * 3/16)
                    image.set(x-1, y+1, nei_p)

                # Pushing 5/16 of difference down
                if y < height - 1:
                    nei_p = image.get(x, y+1)
                    nei_p[0] += round(re * 5/16)
                    nei_p[1] += round(ge * 5/16)
                    nei_p[2] += round(be * 5/16)
                    image.set(x, y+1, nei_p)

                # Pushing 1/16 of difference left down
                if x < width - 1 and y < height - 1:
                    nei_p = image.get(x+1, y+1)
                    nei_p[0] += round(re * 1/16)
                    nei_p[1] += round(ge * 1/16)
                    nei_p[2] += round(be * 1/16)
                    image.set(x+1, y+1, nei_p)

            lines.append(line)
        return lines

    @staticmethod
    def dct(matrix):
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

    @staticmethod
    def idct(matrix):
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

    @staticmethod
    def entropize(matrix, quality):
        d = range(quality)
        line = list(d)
        p = Eidon.Matrix.ZIGZAG
        for i in d:
            line[i] = int(matrix[p[i][1]][p[i][0]] + 128)
        return line

    @staticmethod
    def deentropize(line):
        m = [[0. for _ in range(8)] for _ in range(8)]
        p = Eidon.Matrix.ZIGZAG
        for i in range(min(len(line), 64)):
            m[p[i][1]][p[i][0]] = line[i] - 128
        return m

    @staticmethod
    def quantize(matrix, factor):
        for y in range(8):
            for x in range(8):
                matrix[y][x] = round(matrix[y][x] / factor[y][x])
        return matrix

    @staticmethod
    def dequantize(matrix, factor):
        for y in range(8):
            for x in range(8):
                matrix[y][x] = round(matrix[y][x] * factor[y][x])
        return matrix

    @staticmethod
    def compose(components, size, palette):
        dist = Eidon.Lambda.distance()
        composite = []

        for p in range(size):
            (new_i, new_p) = min(
                enumerate(palette), key=lambda x: (dist(x[1], (
                    components[0][p],
                    components[1][p],
                    components[2][p])), x))
            composite.append(new_i)
        return composite

    @staticmethod
    def decompose(composite, size, palette):
        components = [[], [], []]

        for p in range(size):
            pixel = palette[composite[p]]
            components[0].append(pixel[0])
            components[1].append(pixel[1])
            components[2].append(pixel[2])

        return components

    @staticmethod
    def pack_stream(stream, offset, data):
        for i in range(len(data)):
            stream[offset+i] = data[i]
        return offset + i + 1

    @staticmethod
    def get_matrix(lines, palette, y_pos, x_pos):
        matrix = [[[0. for _ in range(8)] for _ in range(8)] for _ in range(3)]
        for y in range(8):
            for x in range(8):
                pixel = palette[lines[y_pos+y][x_pos+x]]
                matrix[0][y][x] = pixel[0]
                matrix[1][y][x] = pixel[1]
                matrix[2][y][x] = pixel[2]
        return matrix

    @staticmethod
    def set_matrix(image, matrix, y_pos, x_pos, converter):
        for y in range(8):
            for x in range(8):
                image.set(
                    x_pos + x, y_pos + y,
                    converter((
                        matrix[0][y][x],
                        matrix[1][y][x],
                        matrix[2][y][x]
                    ))
                )
        return matrix

    @staticmethod
    def header(meta):
        h = b'Eidos10'
        m = bytes(0x00)

        if meta.quality is Eidon.Quality.BAD:
            m = m | Eidon.Flags.Q_BAD
        elif meta.quality is Eidon.Quality.GOOD:
            m = m | Eidon.Flags.Q_GOOD
        elif meta.quality is Eidon.Quality.BEST:
            m = m | Eidon.Flags.Q_BEST
        else:
            raise RuntimeError('Quality not set in meta.')

        if meta.space is Eidon.Space.YCBCR:
            m = m | Eidon.Flags.CS_YCBCR
        elif meta.space is Eidon.Space.RGB:
            m = m | Eidon.Flags.CS_RGB
        elif meta.space is Eidon.Space.GRAY:
            m = m | Eidon.Flags.CS_GRAY
        else:
            raise RuntimeError('Color space not set in meta.')

        if meta.signal is Eidon.Signal.COMPONENT:
            m = m | Eidon.Flags.S_COMPONENT
        elif meta.signal is Eidon.Signal.COMPOSITE:
            pass
        else:
            raise RuntimeError('Signal unknown error')

        if meta.priority is Eidon.Priority.BRIGHT:
            m = m | Eidon.Flags.P_BRIGHT
        elif meta.priority is Eidon.Priority.COLORFUL:
            pass
        else:
            raise RuntimeError('Priority unknown error')

        return h + m

    class Lambda:
        @staticmethod
        def distance():
            return lambda p1, p2: math.sqrt(
                (p2[0]-p1[0])**2+(p2[1]-p1[1])**2+(p2[2]-p1[2])**2)

        @staticmethod
        def fraction():
            return lambda f, a=0: list(
                i/(f-1)-a for i in list(range(f+1)))[:-1]

        @staticmethod
        def space():
            return lambda fx, fy, fz: [
                (x, y, z) for x in fx for y in fz for z in fy]

        @staticmethod
        def empty():
            return lambda n: list((.0, .0, .0) for x in range(n))

        @staticmethod
        def rgb_676():
            f = Eidon.Lambda.fraction()
            s = Eidon.Lambda.space()
            m = Eidon.Lambda.y_ub8_2()
            e = Eidon.Lambda.empty()
            return lambda: m(s(f(6), f(7), f(6)) + e(4))

        @staticmethod
        def ycbcr_766():
            f = Eidon.Lambda.fraction()
            s = Eidon.Lambda.space()
            m = Eidon.Lambda.y_ub8()
            e = Eidon.Lambda.empty()
            return lambda: m(s(f(7), f(6, .5), f(6, .5)) + e(4))

        @staticmethod
        def ycbcr_1055():
            f = Eidon.Lambda.fraction()
            s = Eidon.Lambda.space()
            m = Eidon.Lambda.y_ub8()
            e = Eidon.Lambda.empty()
            return lambda: m(s(f(10), f(5, .5), f(5, .5)) + e(6))

        @staticmethod
        def y_ub8():
            return lambda s: [(
                min(max(0, round(255 * c[0])), 255),
                min(max(0, round(255 * c[1] + 128)), 255),
                min(max(0, round(255 * c[2] + 128)), 255),
                ) for c in s]

        @staticmethod
        def y_ub8_2():
            return lambda s: [(
                min(max(0, round(255 * c[0])), 255),
                min(max(0, round(255 * c[1])), 255),
                min(max(0, round(255 * c[2])), 255),
                ) for c in s]

        @staticmethod
        def nearest():
            d = Eidon.Lambda.distance()
            s = enumerate(Eidon.Palette.YCBCR766RGB)
            return lambda c: min(s, key=lambda x: (d(x[1], c), x))

        @staticmethod
        def index(width, height, size):
            return lambda x, y: y * width + x * size

        @staticmethod
        def closest():
            return lambda h, l: min(l, key=lambda x: abs(x-h))

        @staticmethod
        def get_pixel(size, data):
            return lambda o: [data[o+c] for c in range(size)]

        @staticmethod
        def set_pixel(size, data):
            return lambda o, p: [operator.setitem(
                p[c], o+c, data) for c in range(size)]

        @staticmethod
        def rgb2ycbcr():
            return lambda c: (
                min(max(0, round(.299 * c[0] + .587 * c[1] + .114 * c[2]))),
                min(max(0, round((-.299 * c[0] - .587 * c[1 + .886] * c[2]) / 1.772 + 128)), 255),  # noqa E501
                min(max(0, round((.701 * c[0] - .587 * c[1] - .114 * c[2]) / 1.402 + 128)), 255)  # noqa E501
            )

        @staticmethod
        def ycbcr2rgb():
            return lambda c: (
                min(max(0, round(c[0] + 1.402 * (c[2] - 128))), 255),
                min(max(0, round(c[0] - (0.114 * 1.772 * (c[1] - 128) + 0.299 * 1.402 * (c[2] - 128)) / 0.587)), 255),  # noqa E501
                min(max(0, round(c[0] + 1.772 * (c[1] - 128))), 255)
            )

        @staticmethod
        def matrix_8x8():
            return lambda: [[0. for _ in range(8)] for _ in range(8)]

    class Quality(enum.IntEnum):
        BAD = 1
        GOOD = 2
        BETTER = 3
        BEST = 4

    class Signal(enum.IntEnum):
        COMPONENT = True
        COMPOSITE = False

    class Format(enum.IntEnum):
        NONE = 0
        INDEX = 1
        GRAYSCALE = 2
        RGB = 3
        YCBCR = 4
        RGBA = 5
        YCBCRA = 6

    class Flags(enum.Flag):
        Q_BAD = enum.auto()
        Q_GOOD = enum.auto()
        Q_BEST = Q_BAD | Q_GOOD

        CS_YCBCR = enum.auto()
        CS_RGB = enum.auto()
        CS_GRAY = CS_YCBCR | CS_RGB

        S_COMPOSITE = enum.auto()

        R_2 = enum.auto()
        R_3 = enum.auto()
        R_4 = enum.auto()

    class Meta(types.SimpleNamespace):
        def __init__(self, quality, signal, space):
            types.SimpleNamespace.__init__(
                self, quality=quality, signal=signal, space=space)

    class Image(types.SimpleNamespace):
        def __init__(self, format, width=0, height=0, data=None, palette=None):

            size = Eidon.SIZES[format]
            Eidon.Image.__validate(format, data, width, height, palette, size)

            if not bool(data):
                data = memoryview(bytearray(b'\x00' * (width * height * size)))
            else:
                data = memoryview(bytearray(data))

            types.SimpleNamespace.__init__(self, format=format, width=width,
                                           height=height, data=data,
                                           palette=palette, size=size)

        @staticmethod
        def __validate(cf, data, width, height, palette, size):
            if cf not in [Eidon.Format.INDEX, Eidon.Format.RGB,
                          Eidon.Format.RGBA, Eidon.Format.YCBCR]:
                raise TypeError('Unknown or unsupported color format')

            if bool(data):
                if len(data) != (width * height * size):
                    raise ValueError('Length of data doesn\'t fit the metrics')

            if cf == Eidon.Format.INDEX and palette is None:
                raise ValueError('Palette requiered with indexed colors')

        def get(self, x, y):
            if x > self.width or y > self.height:
                raise ValueError(
                    'Outside! width: {0}, {1}; height: {2}, {3};'.format(
                        self.width, x, self.height, y))
            else:
                index = (y * self.width + x) * self.size
                return self.data[index:index+self.size].tolist()

        def set(self, x, y, p):
            if x > self.width or y > self.width:
                raise ValueError(
                    'Outside! width: {0}, {1}; height: {2}, {3};'.format(
                        self.width, y, self.height, x))
            index = (y * self.width + x) * self.size
            if isinstance(p, int):
                self.data.obj[index] = min(max(0, p), 255)
            else:
                for j in range(len(p)):
                    self.data.obj[index + j] = min(max(0, p[j]), 255)

    class Palette:
        YCBCR766 = (
            (0, 0, 0),       (0, 0, 52),      (0, 0, 102),     (0, 0, 154),
            (0, 0, 204),     (0, 0, 255),     (0, 52, 0),      (0, 52, 52),
            (0, 52, 102),    (0, 52, 154),    (0, 52, 204),    (0, 52, 255),
            (0, 102, 0),     (0, 102, 52),    (0, 102, 102),   (0, 102, 154),
            (0, 102, 204),   (0, 102, 255),   (0, 154, 0),     (0, 154, 52),
            (0, 154, 102),   (0, 154, 154),   (0, 154, 204),   (0, 154, 255),
            (0, 204, 0),     (0, 204, 52),    (0, 204, 102),   (0, 204, 154),
            (0, 204, 204),   (0, 204, 255),   (0, 255, 0),     (0, 255, 52),
            (0, 255, 102),   (0, 255, 154),   (0, 255, 204),   (0, 255, 255),
            (42, 0, 0),      (42, 0, 52),     (42, 0, 102),    (42, 0, 154),
            (42, 0, 204),    (42, 0, 255),    (42, 52, 0),     (42, 52, 52),
            (42, 52, 102),   (42, 52, 154),   (42, 52, 204),   (42, 52, 255),
            (42, 102, 0),    (42, 102, 52),   (42, 102, 102),  (42, 102, 154),
            (42, 102, 204),  (42, 102, 255),  (42, 154, 0),    (42, 154, 52),
            (42, 154, 102),  (42, 154, 154),  (42, 154, 204),  (42, 154, 255),
            (42, 204, 0),    (42, 204, 52),   (42, 204, 102),  (42, 204, 154),
            (42, 204, 204),  (42, 204, 255),  (42, 255, 0),    (42, 255, 52),
            (42, 255, 102),  (42, 255, 154),  (42, 255, 204),  (42, 255, 255),
            (85, 0, 0),      (85, 0, 52),     (85, 0, 102),    (85, 0, 154),
            (85, 0, 204),    (85, 0, 255),    (85, 52, 0),     (85, 52, 52),
            (85, 52, 102),   (85, 52, 154),   (85, 52, 204),   (85, 52, 255),
            (85, 102, 0),    (85, 102, 52),   (85, 102, 102),  (85, 102, 154),
            (85, 102, 204),  (85, 102, 255),  (85, 154, 0),    (85, 154, 52),
            (85, 154, 102),  (85, 154, 154),  (85, 154, 204),  (85, 154, 255),
            (85, 204, 0),    (85, 204, 52),   (85, 204, 102),  (85, 204, 154),
            (85, 204, 204),  (85, 204, 255),  (85, 255, 0),    (85, 255, 52),
            (85, 255, 102),  (85, 255, 154),  (85, 255, 204),  (85, 255, 255),
            (128, 0, 0),     (128, 0, 52),    (128, 0, 102),   (128, 0, 154),
            (128, 0, 204),   (128, 0, 255),   (128, 52, 0),    (128, 52, 52),
            (128, 52, 102),  (128, 52, 154),  (128, 52, 204),  (128, 52, 255),
            (128, 102, 0),   (128, 102, 52),  (128, 102, 102), (128, 102, 154),
            (128, 102, 204), (128, 102, 255), (128, 154, 0),   (128, 154, 52),
            (128, 154, 102), (128, 154, 154), (128, 154, 204), (128, 154, 255),
            (128, 204, 0),   (128, 204, 52),  (128, 204, 102), (128, 204, 154),
            (128, 204, 204), (128, 204, 255), (128, 255, 0),   (128, 255, 52),
            (128, 255, 102), (128, 255, 154), (128, 255, 204), (128, 255, 255),
            (170, 0, 0),     (170, 0, 52),    (170, 0, 102),   (170, 0, 154),
            (170, 0, 204),   (170, 0, 255),   (170, 52, 0),    (170, 52, 52),
            (170, 52, 102),  (170, 52, 154),  (170, 52, 204),  (170, 52, 255),
            (170, 102, 0),   (170, 102, 52),  (170, 102, 102), (170, 102, 154),
            (170, 102, 204), (170, 102, 255), (170, 154, 0),   (170, 154, 52),
            (170, 154, 102), (170, 154, 154), (170, 154, 204), (170, 154, 255),
            (170, 204, 0),   (170, 204, 52),  (170, 204, 102), (170, 204, 154),
            (170, 204, 204), (170, 204, 255), (170, 255, 0),   (170, 255, 52),
            (170, 255, 102), (170, 255, 154), (170, 255, 204), (170, 255, 255),
            (212, 0, 0),     (212, 0, 52),    (212, 0, 102),   (212, 0, 154),
            (212, 0, 204),   (212, 0, 255),   (212, 52, 0),    (212, 52, 52),
            (212, 52, 102),  (212, 52, 154),  (212, 52, 204),  (212, 52, 255),
            (212, 102, 0),   (212, 102, 52),  (212, 102, 102), (212, 102, 154),
            (212, 102, 204), (212, 102, 255), (212, 154, 0),   (212, 154, 52),
            (212, 154, 102), (212, 154, 154), (212, 154, 204), (212, 154, 255),
            (212, 204, 0),   (212, 204, 52),  (212, 204, 102), (212, 204, 154),
            (212, 204, 204), (212, 204, 255), (212, 255, 0),   (212, 255, 52),
            (212, 255, 102), (212, 255, 154), (212, 255, 204), (212, 255, 255),
            (255, 0, 0),     (255, 0, 52),    (255, 0, 102),   (255, 0, 154),
            (255, 0, 204),   (255, 0, 255),   (255, 52, 0),    (255, 52, 52),
            (255, 52, 102),  (255, 52, 154),  (255, 52, 204),  (255, 52, 255),
            (255, 102, 0),   (255, 102, 52),  (255, 102, 102), (255, 102, 154),
            (255, 102, 204), (255, 102, 255), (255, 154, 0),   (255, 154, 52),
            (255, 154, 102), (255, 154, 154), (255, 154, 204), (255, 154, 255),
            (255, 204, 0),   (255, 204, 52),  (255, 204, 102), (255, 204, 154),
            (255, 204, 204), (255, 204, 255), (255, 255, 0),   (255, 255, 52),
            (255, 255, 102), (255, 255, 154), (255, 255, 204), (255, 255, 255),
            (0, 128, 128),   (0, 128, 128),   (0, 128, 128),   (0, 128, 128)
        )

        YCBCR766RGB = (
            (0, 135, 0),     (0, 98, 0),      (0, 63, 0),      (36, 25, 0),
            (107, 0, 0),     (178, 0, 0),     (0, 118, 0),     (0, 80, 0),
            (0, 45, 0),      (36, 8, 0),      (107, 0, 0),     (178, 0, 0),
            (0, 100, 0),     (0, 63, 0),      (0, 28, 0),      (36, 0, 0),
            (107, 0, 0),     (178, 0, 0),     (0, 82, 46),     (0, 45, 46),
            (0, 10, 46),     (36, 0, 46),     (107, 0, 46),    (178, 0, 46),
            (0, 65, 135),    (0, 28, 135),    (0, 0, 135),     (36, 0, 135),
            (107, 0, 135),   (178, 0, 135),   (0, 48, 225),    (0, 11, 225),
            (0, 0, 225),     (36, 0, 225),    (107, 0, 225),   (178, 0, 225),
            (0, 177, 0),     (0, 140, 0),     (6, 105, 0),     (78, 67, 0),
            (149, 32, 0),    (220, 0, 0),     (0, 160, 0),     (0, 122, 0),
            (6, 87, 0),      (78, 50, 0),     (149, 14, 0),    (220, 0, 0),
            (0, 142, 0),     (0, 105, 0),     (6, 70, 0),      (78, 32, 0),
            (149, 0, 0),     (220, 0, 0),     (0, 124, 88),    (0, 87, 88),
            (6, 52, 88),     (78, 14, 88),    (149, 0, 88),    (220, 0, 88),
            (0, 107, 177),   (0, 70, 177),    (6, 34, 177),    (78, 0, 177),
            (149, 0, 177),   (220, 0, 177),   (0, 90, 255),    (0, 53, 255),
            (6, 17, 255),    (78, 0, 255),    (149, 0, 255),   (220, 0, 255),
            (0, 220, 0),     (0, 183, 0),     (49, 148, 0),    (121, 110, 0),
            (192, 75, 0),    (255, 38, 0),    (0, 203, 0),     (0, 165, 0),
            (49, 130, 0),    (121, 93, 0),    (192, 57, 0),    (255, 20, 0),
            (0, 185, 39),    (0, 148, 39),    (49, 113, 39),   (121, 75, 39),
            (192, 40, 39),   (255, 3, 39),    (0, 167, 131),   (0, 130, 131),
            (49, 95, 131),   (121, 57, 131),  (192, 22, 131),  (255, 0, 131),
            (0, 150, 220),   (0, 113, 220),   (49, 77, 220),   (121, 40, 220),
            (192, 5, 220),   (255, 0, 220),   (0, 133, 255),   (0, 96, 255),
            (49, 60, 255),   (121, 23, 255),  (192, 0, 255),   (255, 0, 255),
            (0, 255, 0),     (21, 226, 0),    (92, 191, 0),    (164, 153, 0),
            (235, 118, 0),   (255, 81, 0),    (0, 246, 0),     (21, 208, 0),
            (92, 173, 0),    (164, 136, 0),   (235, 100, 0),   (255, 63, 0),
            (0, 228, 82),    (21, 191, 82),   (92, 156, 82),   (164, 118, 82),
            (235, 83, 82),   (255, 46, 82),   (0, 210, 174),   (21, 173, 174),
            (92, 138, 174),  (164, 100, 174), (235, 65, 174),  (255, 28, 174),
            (0, 193, 255),   (21, 156, 255),  (92, 120, 255),  (164, 83, 255),
            (235, 48, 255),  (255, 11, 255),  (0, 176, 255),   (21, 139, 255),
            (92, 103, 255),  (164, 66, 255),  (235, 30, 255),  (255, 0, 255),
            (0, 255, 0),     (63, 255, 0),    (134, 233, 0),   (206, 195, 0),
            (255, 160, 0),   (255, 123, 0),   (0, 255, 35),    (63, 250, 35),
            (134, 215, 35),  (206, 178, 35),  (255, 142, 35),  (255, 105, 35),
            (0, 255, 124),   (63, 233, 124),  (134, 198, 124), (206, 160, 124),
            (255, 125, 124), (255, 88, 124),  (0, 252, 216),   (63, 215, 216),
            (134, 180, 216), (206, 142, 216), (255, 107, 216), (255, 70, 216),
            (0, 235, 255),   (63, 198, 255),  (134, 162, 255), (206, 125, 255),
            (255, 90, 255),  (255, 53, 255),  (0, 218, 255),   (63, 181, 255),
            (134, 145, 255), (206, 108, 255), (255, 72, 255),  (255, 36, 255),
            (33, 255, 0),    (105, 255, 0),   (176, 255, 0),   (248, 237, 0),
            (255, 202, 0),   (255, 165, 0),   (33, 255, 77),   (105, 255, 77),
            (176, 255, 77),  (248, 220, 77),  (255, 184, 77),  (255, 147, 77),
            (33, 255, 166),  (105, 255, 166), (176, 240, 166), (248, 202, 166),
            (255, 167, 166), (255, 130, 166), (33, 255, 255),  (105, 255, 255),
            (176, 222, 255), (248, 184, 255), (255, 149, 255), (255, 112, 255),
            (33, 255, 255),  (105, 240, 255), (176, 204, 255), (248, 167, 255),
            (255, 132, 255), (255, 95, 255),  (33, 255, 255),  (105, 223, 255),
            (176, 187, 255), (248, 150, 255), (255, 114, 255), (255, 78, 255),
            (76, 255, 28),   (148, 255, 28),  (219, 255, 28),  (255, 255, 28),
            (255, 245, 28),  (255, 208, 28),  (76, 255, 120),  (148, 255, 120),
            (219, 255, 120), (255, 255, 120), (255, 227, 120), (255, 190, 120),
            (76, 255, 209),  (148, 255, 209), (219, 255, 209), (255, 245, 209),
            (255, 210, 209), (255, 173, 209), (76, 255, 255),  (148, 255, 255),
            (219, 255, 255), (255, 227, 255), (255, 192, 255), (255, 155, 255),
            (76, 255, 255),  (148, 255, 255), (219, 247, 255), (255, 210, 255),
            (255, 175, 255), (255, 138, 255), (76, 255, 255),  (148, 255, 255),
            (219, 230, 255), (255, 193, 255), (255, 157, 255), (255, 121, 255),
            (0, 0, 0),       (0, 0, 0),       (0, 0, 0),       (0, 0, 0)
        )

        YCBCR1055 = (
            (0, 0, 0),       (0, 0, 64),      (0, 0, 128),     (0, 0, 192),
            (0, 0, 255),     (0, 64, 0),      (0, 64, 64),     (0, 64, 128),
            (0, 64, 192),    (0, 64, 255),    (0, 128, 0),     (0, 128, 64),
            (0, 128, 128),   (0, 128, 192),   (0, 128, 255),   (0, 192, 0),
            (0, 192, 64),    (0, 192, 128),   (0, 192, 192),   (0, 192, 255),
            (0, 255, 0),     (0, 255, 64),    (0, 255, 128),   (0, 255, 192),
            (0, 255, 255),   (28, 0, 0),      (28, 0, 64),     (28, 0, 128),
            (28, 0, 192),    (28, 0, 255),    (28, 64, 0),     (28, 64, 64),
            (28, 64, 128),   (28, 64, 192),   (28, 64, 255),   (28, 128, 0),
            (28, 128, 64),   (28, 128, 128),  (28, 128, 192),  (28, 128, 255),
            (28, 192, 0),    (28, 192, 64),   (28, 192, 128),  (28, 192, 192),
            (28, 192, 255),  (28, 255, 0),    (28, 255, 64),   (28, 255, 128),
            (28, 255, 192),  (28, 255, 255),  (57, 0, 0),      (57, 0, 64),
            (57, 0, 128),    (57, 0, 192),    (57, 0, 255),    (57, 64, 0),
            (57, 64, 64),    (57, 64, 128),   (57, 64, 192),   (57, 64, 255),
            (57, 128, 0),    (57, 128, 64),   (57, 128, 128),  (57, 128, 192),
            (57, 128, 255),  (57, 192, 0),    (57, 192, 64),   (57, 192, 128),
            (57, 192, 192),  (57, 192, 255),  (57, 255, 0),    (57, 255, 64),
            (57, 255, 128),  (57, 255, 192),  (57, 255, 255),  (85, 0, 0),
            (85, 0, 64),     (85, 0, 128),    (85, 0, 192),    (85, 0, 255),
            (85, 64, 0),     (85, 64, 64),    (85, 64, 128),   (85, 64, 192),
            (85, 64, 255),   (85, 128, 0),    (85, 128, 64),   (85, 128, 128),
            (85, 128, 192),  (85, 128, 255),  (85, 192, 0),    (85, 192, 64),
            (85, 192, 128),  (85, 192, 192),  (85, 192, 255),  (85, 255, 0),
            (85, 255, 64),   (85, 255, 128),  (85, 255, 192),  (85, 255, 255),
            (113, 0, 0),     (113, 0, 64),    (113, 0, 128),   (113, 0, 192),
            (113, 0, 255),   (113, 64, 0),    (113, 64, 64),   (113, 64, 128),
            (113, 64, 192),  (113, 64, 255),  (113, 128, 0),   (113, 128, 64),
            (113, 128, 128), (113, 128, 192), (113, 128, 255), (113, 192, 0),
            (113, 192, 64),  (113, 192, 128), (113, 192, 192), (113, 192, 255),
            (113, 255, 0),   (113, 255, 64),  (113, 255, 128), (113, 255, 192),
            (113, 255, 255), (142, 0, 0),     (142, 0, 64),    (142, 0, 128),
            (142, 0, 192),   (142, 0, 255),   (142, 64, 0),    (142, 64, 64),
            (142, 64, 128),  (142, 64, 192),  (142, 64, 255),  (142, 128, 0),
            (142, 128, 64),  (142, 128, 128), (142, 128, 192), (142, 128, 255),
            (142, 192, 0),   (142, 192, 64),  (142, 192, 128), (142, 192, 192),
            (142, 192, 255), (142, 255, 0),   (142, 255, 64),  (142, 255, 128),
            (142, 255, 192), (142, 255, 255), (170, 0, 0),     (170, 0, 64),
            (170, 0, 128),   (170, 0, 192),   (170, 0, 255),   (170, 64, 0),
            (170, 64, 64),   (170, 64, 128),  (170, 64, 192),  (170, 64, 255),
            (170, 128, 0),   (170, 128, 64),  (170, 128, 128), (170, 128, 192),
            (170, 128, 255), (170, 192, 0),   (170, 192, 64),  (170, 192, 128),
            (170, 192, 192), (170, 192, 255), (170, 255, 0),   (170, 255, 64),
            (170, 255, 128), (170, 255, 192), (170, 255, 255), (198, 0, 0),
            (198, 0, 64),    (198, 0, 128),   (198, 0, 192),   (198, 0, 255),
            (198, 64, 0),    (198, 64, 64),   (198, 64, 128),  (198, 64, 192),
            (198, 64, 255),  (198, 128, 0),   (198, 128, 64),  (198, 128, 128),
            (198, 128, 192), (198, 128, 255), (198, 192, 0),   (198, 192, 64),
            (198, 192, 128), (198, 192, 192), (198, 192, 255), (198, 255, 0),
            (198, 255, 64),  (198, 255, 128), (198, 255, 192), (198, 255, 255),
            (227, 0, 0),     (227, 0, 64),    (227, 0, 128),   (227, 0, 192),
            (227, 0, 255),   (227, 64, 0),    (227, 64, 64),   (227, 64, 128),
            (227, 64, 192),  (227, 64, 255),  (227, 128, 0),   (227, 128, 64),
            (227, 128, 128), (227, 128, 192), (227, 128, 255), (227, 192, 0),
            (227, 192, 64),  (227, 192, 128), (227, 192, 192), (227, 192, 255),
            (227, 255, 0),   (227, 255, 64),  (227, 255, 128), (227, 255, 192),
            (227, 255, 255), (255, 0, 0),     (255, 0, 64),    (255, 0, 128),
            (255, 0, 192),   (255, 0, 255),   (255, 64, 0),    (255, 64, 64),
            (255, 64, 128),  (255, 64, 192),  (255, 64, 255),  (255, 128, 0),
            (255, 128, 64),  (255, 128, 128), (255, 128, 192), (255, 128, 255),
            (255, 192, 0),   (255, 192, 64),  (255, 192, 128), (255, 192, 192),
            (255, 192, 255), (255, 255, 0),   (255, 255, 64),  (255, 255, 128),
            (255, 255, 192), (255, 255, 255), (0, 128, 128),   (0, 128, 128),
            (0, 128, 128),   (0, 128, 128),   (0, 128, 128),   (0, 128, 128)
        )

        RGB676 = (
            (0, 0, 0),       (0, 0, 42),      (0, 0, 85),      (0, 0, 128),
            (0, 0, 170),     (0, 0, 212),     (0, 0, 255),     (0, 51, 0),
            (0, 51, 42),     (0, 51, 85),     (0, 51, 128),    (0, 51, 170),
            (0, 51, 212),    (0, 51, 255),    (0, 102, 0),     (0, 102, 42),
            (0, 102, 85),    (0, 102, 128),   (0, 102, 170),   (0, 102, 212),
            (0, 102, 255),   (0, 153, 0),     (0, 153, 42),    (0, 153, 85),
            (0, 153, 128),   (0, 153, 170),   (0, 153, 212),   (0, 153, 255),
            (0, 204, 0),     (0, 204, 42),    (0, 204, 85),    (0, 204, 128),
            (0, 204, 170),   (0, 204, 212),   (0, 204, 255),   (0, 255, 0),
            (0, 255, 42),    (0, 255, 85),    (0, 255, 128),   (0, 255, 170),
            (0, 255, 212),   (0, 255, 255),   (51, 0, 0),      (51, 0, 42),
            (51, 0, 85),     (51, 0, 128),    (51, 0, 170),    (51, 0, 212),
            (51, 0, 255),    (51, 51, 0),     (51, 51, 42),    (51, 51, 85),
            (51, 51, 128),   (51, 51, 170),   (51, 51, 212),   (51, 51, 255),
            (51, 102, 0),    (51, 102, 42),   (51, 102, 85),   (51, 102, 128),
            (51, 102, 170),  (51, 102, 212),  (51, 102, 255),  (51, 153, 0),
            (51, 153, 42),   (51, 153, 85),   (51, 153, 128),  (51, 153, 170),
            (51, 153, 212),  (51, 153, 255),  (51, 204, 0),    (51, 204, 42),
            (51, 204, 85),   (51, 204, 128),  (51, 204, 170),  (51, 204, 212),
            (51, 204, 255),  (51, 255, 0),    (51, 255, 42),   (51, 255, 85),
            (51, 255, 128),  (51, 255, 170),  (51, 255, 212),  (51, 255, 255),
            (102, 0, 0),     (102, 0, 42),    (102, 0, 85),    (102, 0, 128),
            (102, 0, 170),   (102, 0, 212),   (102, 0, 255),   (102, 51, 0),
            (102, 51, 42),   (102, 51, 85),   (102, 51, 128),  (102, 51, 170),
            (102, 51, 212),  (102, 51, 255),  (102, 102, 0),   (102, 102, 42),
            (102, 102, 85),  (102, 102, 128), (102, 102, 170), (102, 102, 212),
            (102, 102, 255), (102, 153, 0),   (102, 153, 42),  (102, 153, 85),
            (102, 153, 128), (102, 153, 170), (102, 153, 212), (102, 153, 255),
            (102, 204, 0),   (102, 204, 42),  (102, 204, 85),  (102, 204, 128),
            (102, 204, 170), (102, 204, 212), (102, 204, 255), (102, 255, 0),
            (102, 255, 42),  (102, 255, 85),  (102, 255, 128), (102, 255, 170),
            (102, 255, 212), (102, 255, 255), (153, 0, 0),     (153, 0, 42),
            (153, 0, 85),    (153, 0, 128),   (153, 0, 170),   (153, 0, 212),
            (153, 0, 255),   (153, 51, 0),    (153, 51, 42),   (153, 51, 85),
            (153, 51, 128),  (153, 51, 170),  (153, 51, 212),  (153, 51, 255),
            (153, 102, 0),   (153, 102, 42),  (153, 102, 85),  (153, 102, 128),
            (153, 102, 170), (153, 102, 212), (153, 102, 255), (153, 153, 0),
            (153, 153, 42),  (153, 153, 85),  (153, 153, 128), (153, 153, 170),
            (153, 153, 212), (153, 153, 255), (153, 204, 0),   (153, 204, 42),
            (153, 204, 85),  (153, 204, 128), (153, 204, 170), (153, 204, 212),
            (153, 204, 255), (153, 255, 0),   (153, 255, 42),  (153, 255, 85),
            (153, 255, 128), (153, 255, 170), (153, 255, 212), (153, 255, 255),
            (204, 0, 0),     (204, 0, 42),    (204, 0, 85),    (204, 0, 128),
            (204, 0, 170),   (204, 0, 212),   (204, 0, 255),   (204, 51, 0),
            (204, 51, 42),   (204, 51, 85),   (204, 51, 128),  (204, 51, 170),
            (204, 51, 212),  (204, 51, 255),  (204, 102, 0),   (204, 102, 42),
            (204, 102, 85),  (204, 102, 128), (204, 102, 170), (204, 102, 212),
            (204, 102, 255), (204, 153, 0),   (204, 153, 42),  (204, 153, 85),
            (204, 153, 128), (204, 153, 170), (204, 153, 212), (204, 153, 255),
            (204, 204, 0),   (204, 204, 42),  (204, 204, 85),  (204, 204, 128),
            (204, 204, 170), (204, 204, 212), (204, 204, 255), (204, 255, 0),
            (204, 255, 42),  (204, 255, 85),  (204, 255, 128), (204, 255, 170),
            (204, 255, 212), (204, 255, 255), (255, 0, 0),     (255, 0, 42),
            (255, 0, 85),    (255, 0, 128),   (255, 0, 170),   (255, 0, 212),
            (255, 0, 255),   (255, 51, 0),    (255, 51, 42),   (255, 51, 85),
            (255, 51, 128),  (255, 51, 170),  (255, 51, 212),  (255, 51, 255),
            (255, 102, 0),   (255, 102, 42),  (255, 102, 85),  (255, 102, 128),
            (255, 102, 170), (255, 102, 212), (255, 102, 255), (255, 153, 0),
            (255, 153, 42),  (255, 153, 85),  (255, 153, 128), (255, 153, 170),
            (255, 153, 212), (255, 153, 255), (255, 204, 0),   (255, 204, 42),
            (255, 204, 85),  (255, 204, 128), (255, 204, 170), (255, 204, 212),
            (255, 204, 255), (255, 255, 0),   (255, 255, 42),  (255, 255, 85),
            (255, 255, 128), (255, 255, 170), (255, 255, 212), (255, 255, 255),
            (0, 0, 0),       (0, 0, 0),       (0, 0, 0),       (0, 0, 0)
        )

    class Matrix:
        ZIGZAG = (
            (0, 0), (1, 0), (0, 1), (0, 2), (1, 1), (2, 0), (3, 0), (2, 1),
            (1, 2), (0, 3), (0, 4), (1, 3), (2, 2), (3, 1), (4, 0), (5, 0),
            (4, 1), (3, 2), (2, 3), (1, 4), (0, 5), (0, 6), (1, 5), (2, 4),
            (3, 3), (4, 2), (5, 1), (6, 0), (7, 0), (6, 1), (5, 2), (4, 3),
            (3, 4), (2, 5), (1, 6), (0, 7), (1, 7), (2, 6), (3, 5), (4, 4),
            (5, 3), (6, 2), (7, 1), (7, 2), (6, 3), (5, 4), (4, 5), (3, 6),
            (2, 7), (3, 7), (4, 6), (5, 5), (6, 4), (7, 3), (7, 4), (6, 5),
            (5, 6), (4, 7), (5, 7), (6, 6), (7, 5), (7, 6), (6, 7), (7, 7)
        )

        QUANTITY_Y = (
            (16,  11,  10,  16,  24,  40,  51,  61),
            (12,  12,  14,  19,  26,  58,  60,  55),
            (14,  13,  16,  24,  40,  57,  69,  56),
            (14,  17,  22,  29,  51,  87,  80,  62),
            (18,  22,  37,  56,  68, 109, 103,  77),
            (24,  35,  55,  64,  81, 104, 113,  92),
            (49,  64,  78,  87, 103, 121, 120, 101),
            (72,  92,  95,  98, 112, 100, 103,  99)
        )

        QUANTITY_C = (
            (17,  18,  24,  47,  99,  99,  99,  99),
            (18,  21,  26,  66,  99,  99,  99,  99),
            (24,  26,  56,  99,  99,  99,  99,  99),
            (47,  66,  99,  99,  99,  99,  99,  99),
            (99,  99,  99,  99,  99,  99,  99,  99),
            (99,  99,  99,  99,  99,  99,  99,  99),
            (99,  99,  99,  99,  99,  99,  99,  99),
            (99,  99,  99,  99,  99,  99,  99,  99),
        )
