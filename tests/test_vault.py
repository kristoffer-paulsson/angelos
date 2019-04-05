import sys
sys.path.append('../angelos')  # noqa

import unittest
import tempfile
import os
import logging

from lipsum import LIPSUM
from support import filesize
from angelos.archive.conceal import ConcealIO


class TestConceal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.home = self.dir.name
        self.filename = os.path.join(self.dir.name, 'test.cnl')

    def tearDown(self):
        self.dir.cleanup()

    def test_create_open(self):
        """Creating new empty file and then open file"""
        logging.info('====== %s ======' % 'test_create_open')

        with ConcealIO(self.filename, 'wb', self.secret):
            pass
        self.assertEqual(512*33, filesize(self.filename), 'Wrong filesize.')
        with ConcealIO(self.filename, 'rb+',  self.secret):
            pass
        self.assertEqual(512*33, filesize(self.filename), 'Wrong filesize.')


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
