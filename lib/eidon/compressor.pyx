# cython: language_level=3
"""
#
# Compression application using static arithmetic coding
#
# Usage: python arithmetic-compress.py InputFile OutputFile
# Then use the corresponding arithmetic-decompress.py application to recreate the original input file.
# Note that the application uses an alphabet of 257 symbols - 256 symbols for the byte
# values and 1 symbol for the EOF marker. The compressed file format starts with a list
# of 256 symbol frequencies, and then followed by the arithmetic-coded data.
#
# Copyright (c) Project Nayuki
#
# https://www.nayuki.io/page/reference-arithmetic-coding
# https://github.com/nayuki/Reference-arithmetic-coding
#
# Adapted to Python 3 only, flake 8 compliant and made OO.
"""  # noqa E501

import io

from .arithmetic import (
    BitOutputStream,
    BitInputStream,
    SimpleFrequencyTable,
    ArithmeticEncoder,
    FlatFrequencyTable,
    ArithmeticDecoder,
)


class ArithmethicCompressor:
    def run(self, src):
        input = io.BytesIO(src)
        output = io.BytesIO(bytearray())
        # Read input file once to compute symbol frequencies
        freqs = self.get_frequencies(io.BytesIO(src))
        freqs.increment(256)  # EOF symbol gets a frequency of 1

        bitout = BitOutputStream(output)
        self.write_frequencies(bitout, freqs)
        self.compress(freqs, input, bitout)

        return output.getvalue()

    def get_frequencies(self, input):
        freqs = SimpleFrequencyTable([0] * 257)
        while True:
            b = input.read(1)
            if len(b) == 0:
                break
            b = b[0]
            freqs.increment(b)
        return freqs

    def write_frequencies(self, bitout, freqs):
        for i in range(256):
            self.write_int(bitout, 32, freqs.get(i))

    def compress(self, freqs, inp, bitout):
        enc = ArithmeticEncoder(32, bitout)
        while True:
            symbol = inp.read(1)
            if len(symbol) == 0:
                break
            symbol = symbol[0]
            enc.write(freqs, symbol)
        enc.write(freqs, 256)  # EOF
        enc.finish()  # Flush remaining code bits

    def write_int(self, bitout, numbits, value):
        for i in reversed(range(numbits)):
            bitout.write((value >> i) & 1)  # Big endian


class AdaptiveArithmethicDecompressor:
    def run(self, src):
        input = io.BytesIO(src)
        output = io.BytesIO(bytearray())

        bitin = BitInputStream(input)
        self.decompress(bitin, output)

        return output.getvalue()

    def decompress(self, bitin, out):
        initfreqs = FlatFrequencyTable(257)
        freqs = SimpleFrequencyTable(initfreqs)
        dec = ArithmeticDecoder(32, bitin)
        while True:
            symbol = dec.read(freqs)
            if symbol == 256:
                break
            out.write(bytes((symbol,)))
            freqs.increment(symbol)


class AdaptiveArithmethicCompressor:
    def run(self, src):
        input = io.BytesIO(src)
        output = io.BytesIO(bytearray())

        bitout = BitOutputStream(output)
        self.compress(input, bitout)

        return output.getvalue()

    def compress(self, inp, bitout):
        initfreqs = FlatFrequencyTable(257)
        freqs = SimpleFrequencyTable(initfreqs)
        enc = ArithmeticEncoder(32, bitout)
        while True:
            symbol = inp.read(1)
            if len(symbol) == 0:
                break
            symbol = symbol[0]
            enc.write(freqs, symbol)
            freqs.increment(symbol)
        enc.write(freqs, 256)
        enc.finish()
