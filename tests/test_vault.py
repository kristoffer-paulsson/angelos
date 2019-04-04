import sys
sys.path.append('../angelos')  # noqa

import unittest
import tempfile
import os
import random
import logging

import libnacl.secret

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

    def test_rw_init(self):
        """Writes data to new file, then reopen and read."""
        logging.info('====== %s ======' % 'test_rw_init')

        with ConcealIO(self.filename, 'wb', self.secret) as cnl:
            cnl.write(LIPSUM.encode('utf-8'))
        with ConcealIO(self.filename, 'rb+',  self.secret) as cnl:
            data = cnl.read()
        self.assertEqual(LIPSUM.encode('utf-8'), data, 'Corrupted data.')

    def test_rw_noinit(self):
        """Creates new file, then reopen for write and read."""
        logging.info('====== %s ======' % 'test_rw_noinit')

        with ConcealIO(self.filename, 'wb', self.secret) as cnl:
            pass
        with ConcealIO(self.filename, 'rb+',  self.secret) as cnl:
            cnl.write(LIPSUM.encode('utf-8'))
            cnl.seek(0)
            data = cnl.read()
        self.assertEqual(LIPSUM.encode('utf-8'), data, 'Corrupted data.')

    def test_random_access(self):
        """Create new file, then reopen and write, read write randomly"""
        logging.info('====== %s ======' % 'test_random_access')

        with ConcealIO(self.filename, 'wb', self.secret) as cnl:
            pass
        with ConcealIO(self.filename, 'rb+',  self.secret) as cnl:
            cnl.write(LIPSUM.encode('utf-8'))
            cnl.seek(0)
            data = cnl.read()

            for slc in range(200):
                section = random.randrange(20, 40)
                offset = random.randrange(0, len(LIPSUM) - section)
                if random.randrange(0, 1):
                    cnl.seek(offset)
                    cnl.write(LIPSUM[offset:offset+section].encode('utf-8'))
                else:
                    cnl.seek(offset)
                    data = cnl.read(section)
                    self.assertEqual(
                        LIPSUM[offset:offset+section].encode('utf-8'), data,
                        'The read data is different from data section.')


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
