import math
from .eidon import Eidon


class EidonStream:
    width = 0
    height = 0
    data = bytearray()
    signal = None
    quality = None

    def __init__(self, width, height, quality, data):
        if not isinstance(width, int): raise TypeError()  # noqa E701
        if not 65535 >= width >= 0: raise ValueError()  # noqa E701
        if not isinstance(height, int): raise TypeError()  # noqa E701
        if not 65535 >= height >= 0: raise ValueError()  # noqa E701
        if not isinstance(quality, int): raise TypeError()  # noqa E701
        if not isinstance(data, bytearray): raise TypeError()  # noqa E701

        self.width = width
        self.height = height
        self.data = memoryview(data)
        self.quality = quality
        self._quality = Eidon.QUALITY[quality]
        self._counter = 0

    def clear(self):
        self._counter = 0

    def pack(self, data):
        if not isinstance(data, list): raise TypeError()  # noqa E701
        offset = self._counter * self._quality
        for q in range(self._quality):
            self.data[offset+q] = data[q]
        self._counter += 1

    def unpack(self):
        offset = self._counter * self._quality
        self._counter += 1
        return self.data[offset:offset+self._quality].tolist()

    def size(self):
        return self._size

    @staticmethod
    def preferred(width, height, data=None):
        return StreamYCBCR(width, height, Eidon.Quality.GOOD, data)


class Stream24Bit(EidonStream):
    def __init__(self, width, height, quality, data=None):
        self._size = 3
        if not bool(data):
            data = bytearray(
                b'\x00' *
                int(math.floor(width / 8)) *
                int(math.floor(height / 8)) *
                self._size*Eidon.QUALITY[quality])
        EidonStream.__init__(self, width, height, quality, data)


class StreamRGB(Stream24Bit):
    pass


class StreamYCBCR(Stream24Bit):
    pass
