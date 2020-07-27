# cython: language_level=3
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
import math
import struct
from angelos.eidon.eidon import Eidon


class EidonStream:
    width = 0
    height = 0
    data = bytearray()
    signal = None
    quality = None

    def __init__(self, width, height, signal, quality, data):
        if not isinstance(width, int):
            raise TypeError()  # noqa E701
        if not 65535 >= width >= 0:
            raise ValueError()  # noqa E701
        if not isinstance(height, int):
            raise TypeError()  # noqa E701
        if not 65535 >= height >= 0:
            raise ValueError()  # noqa E701
        if not isinstance(signal, int):
            raise TypeError()  # noqa E701
        if not isinstance(quality, int):
            raise TypeError()  # noqa E701
        if not isinstance(data, bytearray):
            raise TypeError()  # noqa E701

        self.width = width
        self.height = height
        self.data = data
        self.quality = quality
        self.signal = signal
        self._quality = Eidon.QUALITY[quality]
        self._counter = 0

    def clear(self):
        self._counter = 0

    def pack(self, data):
        if not isinstance(data, list):
            raise TypeError()  # noqa E701
        offset = self._counter * self._quality
        for q in range(self._quality):
            self.data[offset + q] = data[q]
        self._counter += 1

    def unpack(self):
        offset = self._counter * self._quality
        self._counter += 1
        return self.data[offset : offset + self._quality].tolist()

    def size(self):
        return self._size

    @staticmethod
    def preferred(width, height, data=None):
        return StreamRGB(width, height, Eidon.Quality.GOOD, data)

    @staticmethod
    def load(data):
        tpl = struct.unpack(Eidon.HEADER_FORMAT, data[: Eidon.HEADER_LENGTH])
        if tpl[0] == Eidon.Format.RGB:
            klass = StreamRGB  # noqa E701
        elif tpl[0] == Eidon.Format.YCBCR:
            klass = StreamYCBCR  # noqa E701
        elif tpl[0] == Eidon.Format.INDEX:
            klass = StreamIndexed  # noqa E701
        else:
            raise TypeError(tpl[0])  # noqa E701

        return klass(
            tpl[3], tpl[4], tpl[1], bytearray(data[Eidon.HEADER_LENGTH :])
        )

    @staticmethod
    def dump(stream):
        if isinstance(stream, StreamRGB):
            format = Eidon.Format.RGB  # noqa E701
        elif isinstance(stream, StreamYCBCR):
            format = Eidon.Format.YCBCR  # noqa E701
        elif isinstance(stream, StreamIndexed):
            format = Eidon.Format.INDEX  # noqa E701
        else:
            raise TypeError()  # noqa E701

        return bytearray(
            struct.pack(
                Eidon.HEADER_FORMAT,
                format,
                stream.quality,
                stream.signal,
                stream.width,
                stream.height,
            )
            + stream.data
        )


class Stream8Bit(EidonStream):
    def __init__(self, width, height, quality, data=None):
        self._size = 1
        if not bool(data):
            data = bytearray(
                b"\x00"
                * int(math.floor(width / 8))
                * int(math.floor(height / 8))
                * Eidon.QUALITY[quality]
            )
        EidonStream.__init__(
            self, width, height, Eidon.Signal.COMPOSITE, quality, data
        )


class StreamIndexed(Stream8Bit):
    pass


class Stream24Bit(EidonStream):
    def __init__(self, width, height, quality, data=None):
        self._size = 3
        if not bool(data):
            data = bytearray(
                b"\x00"
                * int(math.floor(width / 8))
                * int(math.floor(height / 8))
                * self._size
                * Eidon.QUALITY[quality]
            )
        EidonStream.__init__(
            self, width, height, Eidon.Signal.COMPONENT, quality, data
        )


class StreamRGB(Stream24Bit):
    pass


class StreamYCBCR(Stream24Bit):
    pass
