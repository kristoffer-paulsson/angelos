"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import unittest
import tempfile

from dummy.dummy import DummyPolicy


class TestFacade(unittest.TestCase):
    def setUp(self) -> None:
        self.dir = tempfile.TemporaryDirectory()
        self.home = self.dir.name

    def tearDown(self) -> object:
        self.dir.cleanup()

    def test_setup(self):
        """Creating new facade with archives and then open it"""

        try:
            DummyPolicy().create_church_facade(self.home, True)
        except Exception as e:
            self.fail(e)
