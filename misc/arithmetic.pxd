# cython: language_level=3
from cpython cimport array


ctypedef unsigned short symbol_t
ctypedef unsigned char char_t
ctypedef unsigned int freq_t
ctypedef bint bit_t


# cdef freq_t SIZE = 256
# cdef freq_t BITS = 32
# cdef freq_t FULL = 1 << BITS
# cdef freq_t ONE_FOURTH = FULL >> 2
# cdef freq_t ONE_HALF = ONE_FOURTH * 2
# cdef freq_t THREE_FOURTHS = ONE_FOURTH * 3
# cdef freq_t MAX_CODE = FULL - 1

enum CONST:
    SIZE = 256
    BITS = 32
    FULL = 0x100000000
    ONE_FOURTH = 0x40000000
    ONE_HALF = 0x80000000
    THREE_FOURTHS = 0xc0000000
    MAX_CODE = 0xffffffff


ctypedef struct Probability:
    freq_t low
    freq_t high
    freq_t count


cdef class Tree:
    cdef array.array freqs

    cdef unsigned long sum(self, symbol_t i)

    cdef void add(self, symbol_t i, int k)

    cdef symbol_t get(self, symbol_t i)

    cdef Probability probability(self, symbol_t c)

    cdef void reset(self)

    cdef bytes save(self)


cdef class Encoder:
    cdef symbol_t code
    cdef char cidx

    cdef array.array buf_proto
    cdef Tree table

    cdef unsigned int in_len
    cdef unsigned int in_idx

    cdef unsigned int out_len
    cdef unsigned int out_idx

    cdef inline symbol_t get_byte(self, bytes input)

    cdef inline void put_byte(self, array.array output, symbol_t code)

    cdef inline void put_bit(self, array.array output, bit_t bit)

    cdef inline void write(self, array.array output, bit_t bit, int pending)

    cdef bytes encode(self, bytes input)
