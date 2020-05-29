import logging
import os
import sys
import tracemalloc
import uuid
from tempfile import TemporaryDirectory
from unittest import TestCase

from archive7.archive import Archive7

from angelossim.support import run_async


class BaseArchiveTestCase(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.INFO)

        cls.secret = os.urandom(32)

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""

    def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""

        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.filename = os.path.join(self.home, "test.ar7")

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.dir.cleanup()


class TestHeader(TestCase):
    def test_meta_unpack(self):
        self.fail()


class TestArchive7(BaseArchiveTestCase):
    def test_setup(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_open(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            archive.close()

            archive.open(self.filename, self.secret)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_closed(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            self.assertFalse(archive.closed)
            archive.close()
            self.assertTrue(archive.closed)
        except Exception as e:
            self.fail(e)

    def test_close(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_stats(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            header = archive.stats()
            archive.close()

            archive.open(self.filename, self.secret)
            header2 = archive.stats()
            archive.close()

            self.assertEqual(header.id, header2.id)
            self.assertEqual(header.created, header2.created)
        except Exception as e:
            self.fail(e)

    def test_info(self):
        self.fail()

    def test_glob(self):
        self.fail()

    def test_move(self):
        self.fail()

    def test_chmod(self):
        self.fail()

    def test_remove(self):
        self.fail()

    def test_rename(self):
        self.fail()

    def test_isdir(self):
        self.fail()

    def test_isfile(self):
        self.fail()

    def test_islink(self):
        self.fail()

    @run_async
    async def test_mkdir(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            self.assertIsInstance(await archive.mkdir("/first"), uuid.UUID)
            self.assertIsInstance(await archive.mkdir("/first/second"), uuid.UUID)
            self.assertIsInstance(await archive.mkdir("/first/second/third"), uuid.UUID)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_mkfile(self):
        self.fail()

    def test_link(self):
        self.fail()

    def test_save(self):
        self.fail()

    def test_load(self):
        self.fail()
