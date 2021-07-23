# cython: language_level=3, linetrace=True
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


class Matrix:
    ZIGZAG = (
        (0, 0),
        (1, 0),
        (0, 1),
        (0, 2),
        (1, 1),
        (2, 0),
        (3, 0),
        (2, 1),
        (1, 2),
        (0, 3),
        (0, 4),
        (1, 3),
        (2, 2),
        (3, 1),
        (4, 0),
        (5, 0),
        (4, 1),
        (3, 2),
        (2, 3),
        (1, 4),
        (0, 5),
        (0, 6),
        (1, 5),
        (2, 4),
        (3, 3),
        (4, 2),
        (5, 1),
        (6, 0),
        (7, 0),
        (6, 1),
        (5, 2),
        (4, 3),
        (3, 4),
        (2, 5),
        (1, 6),
        (0, 7),
        (1, 7),
        (2, 6),
        (3, 5),
        (4, 4),
        (5, 3),
        (6, 2),
        (7, 1),
        (7, 2),
        (6, 3),
        (5, 4),
        (4, 5),
        (3, 6),
        (2, 7),
        (3, 7),
        (4, 6),
        (5, 5),
        (6, 4),
        (7, 3),
        (7, 4),
        (6, 5),
        (5, 6),
        (4, 7),
        (5, 7),
        (6, 6),
        (7, 5),
        (7, 6),
        (6, 7),
        (7, 7),
    )

    QUANTITY_Y = (
        (16, 11, 10, 16, 24, 40, 51, 61),
        (12, 12, 14, 19, 26, 58, 60, 55),
        (14, 13, 16, 24, 40, 57, 69, 56),
        (14, 17, 22, 29, 51, 87, 80, 62),
        (18, 22, 37, 56, 68, 109, 103, 77),
        (24, 35, 55, 64, 81, 104, 113, 92),
        (49, 64, 78, 87, 103, 121, 120, 101),
        (72, 92, 95, 98, 112, 100, 103, 99),
    )

    QUANTITY_C = (
        (17, 18, 24, 47, 99, 99, 99, 99),
        (18, 21, 26, 66, 99, 99, 99, 99),
        (24, 26, 56, 99, 99, 99, 99, 99),
        (47, 66, 99, 99, 99, 99, 99, 99),
        (99, 99, 99, 99, 99, 99, 99, 99),
        (99, 99, 99, 99, 99, 99, 99, 99),
        (99, 99, 99, 99, 99, 99, 99, 99),
        (99, 99, 99, 99, 99, 99, 99, 99),
    )
