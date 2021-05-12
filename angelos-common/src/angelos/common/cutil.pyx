# cython: language_level=3
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
from libc.stdlib cimport malloc, free


cdef class Data:
    """Data keeps an allocated memory buffer of items of certain size under control."""

    cdef unsigned char *_buffer;
    cdef unsigned long _size;
    cdef unsigned short _item_size;
    cdef readonly unsigned long length;

    def __cinit__(self, unsigned long length, unsigned short item_size):
        self.length = length
        self._item_size = item_size
        self._size = length*item_size
        self._buffer = <unsigned char*>malloc(self._size)

    def __dealloc__(self):
        free(self._buffer)