import sys
sys.path.append('../angelos')  # noqa

import unittest
import tempfile
import os
import random
import uuid
import string

import libnacl.secret

from lipsum import LIPSUM_LINES, LIPSUM_PATH
from support import filesize
from angelos.archive.archive7 import Archive7


class TestConceal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.secret = libnacl.secret.SecretBox().sk
        cls.dir = tempfile.TemporaryDirectory()
        cls.filename = os.path.join(cls.dir.name, 'test.ar7.cnl')
        cls.owner = uuid.uuid4()

    @classmethod
    def tearDownClass(cls):
        cls.dir.cleanup()

    def test_01_setup(self):
        """Creating new empty archive"""
        with Archive7.setup(self.filename, self.secret, owner=self.owner):
            pass
        self.assertEqual(512*33, filesize(self.filename), 'Wrong filesize.')

    def test_02_mkdir(self):
        """Open archive and write directory tree."""
        with Archive7.open(self.filename, self.secret) as arch:
            for dir in LIPSUM_PATH:
                arch.mkdir(dir)

    def test_03_glob(self):
        """Open archive and glob directory tree"""
        with Archive7.open(self.filename, self.secret) as arch:
            tree = arch.glob()
            self.assertListEqual(LIPSUM_PATH, tree, 'Corrupted file tree.')

    def test_04_mkfile(self):
        """Open archive and write random files"""
        with Archive7.open(self.filename, self.secret) as arch:
            for i in range(200):
                data = ('\n'.join(
                    random.choices(
                        LIPSUM_LINES,
                        k=random.randrange(1, 10)))).encode('utf-8')
                filename = random.choices(
                    LIPSUM_PATH, k=1)[0] + '/' + ''.join(
                        random.choices(
                            string.ascii_lowercase + string.digits,
                            k=random.randrange(5, 10))) + '.txt'
                arch.mkfile(filename, data)


"""
    def test_random_access(self):
        "Create new file, then reopen and write, read write randomly"
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
"""

if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
