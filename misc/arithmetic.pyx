# cython: language_level=3, linetrace=True
from cpython import array
from arithmetic cimport symbol_t, Probability, bit_t, char_t, CONST


cdef class Tree:
    def __cinit__(self):
        self.freqs = array.array('L', [0] * (CONST.SIZE+1))

    cdef unsigned long sum(self, symbol_t i):
        cdef unsigned long sum = 0

        while i > 0:
            sum += self.freqs[i]
            i -= ((i) & -(i))
        return sum

    cdef void add(self, symbol_t i, int k):
        while i < CONST.SIZE:
            self.freqs[i] += k
            i += ((i) & -(i))

    cdef symbol_t get(self, symbol_t i):
        return self.sum(i) - self.sum(i-1)

    cdef Probability probability(self, symbol_t c):
        cdef Probability p = (self.freqs[c], self.freqs[c+1], self.freqs[CONST.SIZE+1])
        return p

    cdef void reset(self):
        self.freqs = array.array('L', [0] * (CONST.SIZE+1))

    cdef bytes save(self):
        return self.freqs.tobytes()[0:1024]


cdef class Encoder:
    def __cinit__(self):
        self.buf_proto = array.array('B', b'\x00' * 2048)

    cdef inline symbol_t get_byte(self, bytes input):
        cdef symbol_t c

        if self.in_idx < self.in_len:
            c = input[self.in_idx]
            self.in_idx += 1
        else:
            c = 256

        return c

    cdef inline void put_byte(self, array.array output, symbol_t code):
        if not self.out_idx < self.out_len:
            output.extend(self.buf_proto)
            self.out_len += 2048

        output[self.in_idx] = <char_t>code
        self.in_idx += 1

    cdef inline void put_bit(self, array.array output, bit_t bit):
        self.code <<= bit
        self.cidx += 1

        if self.cidx >= 8:
            self.code = 0
            self.cidx = 0
            self.put_byte(output, self.code)

    cdef inline void write(self, array.array output, bit_t bit, int pending):
        self.put_bit(output, bit);

        for i in range(pending):
            self.put_bit(output, not bit)

    cdef bytes encode(self, bytes input):
        cdef int pending = 0
        cdef symbol_t c
        cdef Probability p

        cdef unsigned int low = 0
        cdef unsigned int high = CONST.MAX_CODE
        cdef unsigned int range

        cdef array.array output = array.array('B', self.buf_proto)

        self.code = 0
        self.cidx = 0

        self.in_len = input.count()
        self.in_idx = 0
        self.out_len = 2048
        self.out_idx = 0

        self.table = Tree()

        while True:
            c = self.get_byte(input)

            p = self.table.probability(c)
            range = high - low + 1
            high = <int>(low + (range * p.high / p.count) - 1)
            low = <int>(low + (range * p.low / p.count))

            while True:
                if high < CONST.ONE_HALF:
                    self.write(output, 0, pending)
                    pending = 0
                elif low >= CONST.ONE_HALF:
                    self.write(output, 1, pending)
                    pending = 0
                elif low >= CONST.ONE_FOURTH and high < CONST.THREE_FOURTHS:
                    pending += 1
                    low -= CONST.ONE_FOURTH
                    high -= CONST.ONE_FOURTH
                else:
                    break
                high <<= 1
                high += 1
                low <<= 1
                high &= CONST.MAX_CODE
                low &= CONST.MAX_CODE

            if c == 256:
                break

        pending += 1;
        if low < CONST.ONE_FOURTH:
            self.write(output, 0, pending)
        else:
            self.write(output, 1, pending)

        return self.table.save() + output.tobytes()[0:self.out_idx]
