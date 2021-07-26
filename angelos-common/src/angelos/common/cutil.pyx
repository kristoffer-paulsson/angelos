#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Collection of utilities implemented fast in Cython.
The goal is to implement a version of all native python types separately in cython."""
import functools

from libc.stdlib cimport malloc, free

ctypedef signed char int8_t
ctypedef signed short int16_t
ctypedef signed long int int32_t
ctypedef signed long long int64_t

ctypedef unsigned char uint8_t
ctypedef unsigned short uint16_t
ctypedef unsigned long int uint32_t
ctypedef unsigned long long uint64_t


cdef inline double fmax(double a, double b) nogil:
    """Maximum float is returned."""
    return a if a > b else b


cdef inline double fmin(double a, double b) nogil:
    """Minimum float is returned. """
    return a if a < b else b


cdef inline int64_t imax(int64_t a, int64_t b) nogil:
    """Maximum integer is returned."""
    return a if a > b else b


cdef inline int64_t imin(int64_t a, int64_t b) nogil:
    """Minimum integer is returned. """
    return a if a < b else b


cdef class _Data:
    """_Data keeps an allocated memory buffer of items of certain size under control."""

    cdef void *_buffer;
    cdef uint32_t _size;
    cdef uint16_t _item_size;
    cdef readonly uint32_t length;

    def __cinit__(self, uint32_t length, uint16_t item_size):
        self.length = length
        self._item_size = item_size
        self._size = length*item_size
        self._buffer = malloc(self._size)

    def __dealloc__(self):
        free(self._buffer)