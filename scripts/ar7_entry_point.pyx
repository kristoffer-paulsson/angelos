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
"""Archive7 utility entry point to be compiled into an executable.

cython --embed -3 -o ./bin/test.c ./bin/test.pyx
gcc -o ./bin/test.o -c ./bin/test.c `./usr/local/bin/python3.7-config --cflags`
gcc -o ./bin/test ./bin/test.o `./usr/local/bin/python3.7-config --ldflags`
"""
from libangelos.archive7.utility import main


if __name__ == '__main__':
    main()