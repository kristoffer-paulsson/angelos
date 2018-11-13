import math
import collections
import struct


class Delta:
    def encode(src):
        if not isinstance(src, bytearray): raise TypeError()  # noqa E701
        dest = bytearray()
        buffer = bytearray()

        freq = Delta.frequency(src)
        mapping = Delta.mapping(freq)
        mapper = Delta.mapper(mapping)

        for c in src:
            buffer += mapper[c]

            while len(buffer) >= 8:
                dest.append(int(buffer[:8], 2))
                buffer = buffer[8:]

        if len(buffer) > 0:
            dest.append(int(buffer, 2) << (8 - len(buffer)))

        return bytearray(
            struct.pack('!IH', len(dest), len(mapping)) + bytearray(
                int(i) for i in mapping) + dest)

    def decode(src):
        pass

    @staticmethod
    def _gamma(t):
        x = []
        y = []
        while(t > 0):
            x.append(t % 2)
            t = int(t / 2)
        for i in range(len(x)-1):
            y.append(0)
        for i in range(len(x)):
            y.append(x.pop())
        # return ''.join(map(str, y))
        return y

    @staticmethod
    def _delta(x):
        t = math.floor(1+math.log(x, 2))
        p = Delta._gamma(t)
        y = []
        while(x > 0):
            y.append(x % 2)
            x = int(x / 2)
        y.pop()
        for i in range(len(y)):
            p.append(y.pop())
        return ''.join(map(str, p)).encode('utf-8')

    @staticmethod
    def frequency(src):
        freqs = {i: 0 for i in range(256)}
        for i in src:
            freqs[i] += 1

        return freqs

    @staticmethod
    def mapping(freqs):
        ordered = collections.OrderedDict(
            sorted(freqs.items(), key=lambda t: t[1], reverse=True))
        return list({k: v for k, v in ordered.items() if bool(v)}.keys())

    @staticmethod
    def mapper(mapping):
        return {mapping[i]: Delta._delta(i+1) for i in range(len(mapping))}

    @staticmethod
    def _decode(x):
        num = 0
        for i in range(len(x)):
            num += (int(x[len(x)-1-i])*(math.pow(2, i)))
        return num

    @staticmethod
    def _undelta(x):
        if x == '1':
            return 1
        else:
            x = list(x)
        t = 0
        v = []
        b = False
        w = []
        c = False
        for i in x:
            if not b:
                if(i == '0'):
                    t += 1
                else:
                    v.append(i)
                    b = True
            elif not c:
                if(t == 0):
                    c = True
                    w.append('1')
                    w.append(i)
                else:
                    v.append(i)
                    t -= 1
            else:
                num = Delta._decode(v)
                if(num == 0):
                    break
                else:
                    w.append(i)
                    num -= 1
        return Delta._decode(w)
