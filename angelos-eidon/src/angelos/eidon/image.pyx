#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#


class EidonImage:
    width = 0
    height = 0
    pixels = bytearray()

    def __init__(self, width, height, pixels):
        if not isinstance(width, int):
            raise TypeError()  # noqa E701
        if not 65535 >= width >= 0:
            raise ValueError()  # noqa E701
        if not isinstance(height, int):
            raise TypeError()  # noqa E701
        if not 65535 >= height >= 0:
            raise ValueError()  # noqa E701
        if not isinstance(pixels, bytearray):
            raise TypeError()  # noqa E701

        self.width = width
        self.height = height
        self.pixels = memoryview(pixels)

    def get(self, x, y):
        raise NotImplementedError()

    def set(self, x, y, pixel):
        raise NotImplementedError()

    @staticmethod
    def rgb(width, height, pixels=None):
        return ImageRGB(width, height)

    @staticmethod
    def rgba(width, height, pixels=None):
        return ImageRGBA(width, height, pixels)


class Image24Bit(EidonImage):
    def __init__(self, width, height, pixels=None):
        if not bool(pixels):
            pixels = bytearray(b"\x00" * width * height * 3)
        EidonImage.__init__(self, width, height, pixels)

    def get(self, x, y):
        if not isinstance(x, int):
            raise TypeError()  # noqa E701
        if not isinstance(y, int):
            raise TypeError()  # noqa E701

        x = min(max(0, x), self.width)
        y = min(max(0, y), self.height)

        index = (y * self.width + x) * 3
        return self.pixels[index : index + 3].tolist()

    def set(self, x, y, pixel):
        if not isinstance(x, int):
            raise TypeError()  # noqa E701
        if not isinstance(y, int):
            raise TypeError()  # noqa E701
        if not isinstance(pixel, (tuple, list)):
            raise TypeError()  # noqa E701

        x = min(max(0, x), self.width)
        y = min(max(0, y), self.height)

        index = (y * self.width + x) * 3
        for i in range(len(pixel)):
            self.pixels.obj[index + i] = min(max(0, pixel[i]), 255)


class ImageRGB(Image24Bit):
    pass


class Image32Bit(EidonImage):
    def __init__(self, width, height, pixels=None):
        if not bool(pixels):
            pixels = bytearray(b"\x00" * width * height * 4)
        EidonImage.__init__(self, width, height, pixels)

    def get(self, x, y):
        if not isinstance(x, int):
            raise TypeError()  # noqa E701
        if not isinstance(y, int):
            raise TypeError()  # noqa E701

        x = min(max(0, x), self.width)
        y = min(max(0, y), self.height)

        index = (y * self.width + x) * 4
        return self.pixels[index : index + 4].tolist()

    def set(self, x, y, pixel):
        if not isinstance(x, int):
            raise TypeError()  # noqa E701
        if not isinstance(y, int):
            raise TypeError()  # noqa E701
        if not isinstance(pixel, (tuple, list)):
            raise TypeError()  # noqa E701

        x = min(max(0, x), self.width)
        y = min(max(0, y), self.height)

        index = (y * self.width + x) * 4
        for i in range(len(pixel)):
            self.pixels[index + i] = min(max(0, pixel[i]), 255)


class ImageRGBA(Image32Bit):
    pass
