import sys
sys.path.append('../angelos')  # noqa

import unittest
import tempfile
import os
import random
import uuid
import string
import logging

import libnacl.secret

from lipsum import LIPSUM_LINES, LIPSUM_PATH
from support import filesize
from angelos.archive.archive7 import Archive7


class TestConceal(unittest.TestCase):
    files1 = None
    files2 = None
    files3 = None
    files4 = None

    @classmethod
    def setUpClass(cls):
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
        cls.secret = libnacl.secret.SecretBox().sk
        cls.dir = tempfile.TemporaryDirectory()
        cls.filename = os.path.join(cls.dir.name, 'test.ar7.cnl')
        cls.owner = uuid.uuid4()

    @classmethod
    def tearDownClass(cls):
        cls.dir.cleanup()

    def generate_data(self):
        return ('\n'.join(
            random.choices(
                LIPSUM_LINES,
                k=random.randrange(1, 10)))).encode('utf-8')

    def generate_filename(self, postfix='.txt'):
        return ''.join(random.choices(
            string.ascii_lowercase + string.digits,
            k=random.randrange(5, 10))) + postfix

    def test_01_setup(self):
        """Creating new empty archive"""
        logging.info('====== %s ======' % 'test_01_setup')

        with Archive7.setup(self.filename, self.secret, owner=self.owner):
            pass
        self.assertEqual(512*33, filesize(self.filename), 'Wrong filesize.')

    def test_02_mkdir(self):
        """Open archive and write directory tree."""
        logging.info('====== %s ======' % 'test_02_mkdir')

        with Archive7.open(self.filename, self.secret) as arch:
            for dir in LIPSUM_PATH:
                arch.mkdir(dir)

    def test_03_glob(self):
        """Open archive and glob directory tree"""
        logging.info('====== %s ======' % 'test_03_glob')

        with Archive7.open(self.filename, self.secret) as arch:
            tree = arch.glob()
            self.assertListEqual(LIPSUM_PATH, tree, 'Corrupted file tree.')

    def test_04_mkfile(self):
        """Open archive and write random files"""
        logging.info('====== %s ======' % 'test_04_mkfile')

        try:
            with Archive7.open(self.filename, self.secret) as arch:
                files = []
                for i in range(200):
                    data = self.generate_data()
                    filename = random.choices(
                        LIPSUM_PATH, k=1)[0] + '/' + self.generate_filename()
                    files.append(filename)
                    arch.mkfile(filename, data)

                random.shuffle(files)
                TestConceal.files1 = files[:10]
                TestConceal.files2 = files[10:20]
                TestConceal.files3 = files[20:30]
                TestConceal.files4 = files[30:40]
        except Exception as e:
            self.fail(e)

    def test_05_load(self):
        """Open archive and load files"""
        logging.info('====== %s ======' % 'test_05_load')
        try:
            with Archive7.open(self.filename, self.secret) as arch:
                for i in arch.glob():
                    if i not in LIPSUM_PATH:
                        arch.load(i)
        except Exception as e:
            self.fail(e)

    def test_06_save(self):
        """Open archive and update some files"""
        logging.info('====== %s ======' % 'test_06_save')

        try:
            with Archive7.open(self.filename, self.secret) as arch:
                for i in TestConceal.files1:
                    arch.save(i, self.generate_data())
                for i in TestConceal.files1:
                    arch.load(i)
        except Exception as e:
            self.fail(e)

    def test_07_remove(self):
        """Open archive and delete some files"""
        logging.info('====== %s ======' % 'test_07_remove')

        try:
            with Archive7.open(self.filename, self.secret) as arch:
                for i in TestConceal.files2:
                    arch.remove(i)
        except Exception as e:
            self.fail(e)

    def test_08_rename(self):
        """Open archive and delete some files"""
        logging.info('====== %s ======' % 'test_08_rename')

        try:
            with Archive7.open(self.filename, self.secret) as arch:
                for i in TestConceal.files3:
                    arch.rename(i, self.generate_filename())
        except Exception as e:
            self.fail(e)

    def test_09_move(self):
        """Open archive and delete some files"""
        logging.info('====== %s ======' % 'test_09_move')

        try:
            with Archive7.open(self.filename, self.secret) as arch:
                for i in TestConceal.files4:
                    arch.move(i, '/')
        except Exception as e:
            self.fail(e)

    def test_10_load2(self):
        """Open archive and load files"""
        logging.info('====== %s ======' % 'test_10_load2')

        try:
            with Archive7.open(self.filename, self.secret) as arch:
                for i in arch.glob():
                    if i not in LIPSUM_PATH:
                        arch.load(i)
        except Exception as e:
            self.fail(e)


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
