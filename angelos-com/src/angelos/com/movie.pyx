#
# Copyright (c) 2018-2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Film format for moving pictures.

κινέω (Kineo) from move.
"""
import math
from array import array


class Kineo:

    def frame(self, width: int, height: int) -> array.array:
        """Create frame."""
        return array.array("f", bytearray(width * height * 4))

    def compress(self, frame: array.array) -> array.array:
        buffer = array.array("f", bytearray(math.ceil(len(frame) / 6)*4))

        (x * y) a