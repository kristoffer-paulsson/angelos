#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import os
from unittest import TestCase

from bplustree.utils import iter_slice


class Test(TestCase):
    def test_iter_slice(self):
        try:
            data = os.urandom(2342)
            index = 0
            is_last = None
            for slc, is_last in iter_slice(data, 23):
                another = data[index*23: index*23+23]
                self.assertEqual(slc, another)
                index += 1
            self.assertTrue(is_last)
        except Exception as e:
            self.fail(e)

    def test_pairwise(self):
        self.fail()
