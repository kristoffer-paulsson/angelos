import hashlib
import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from archive7.streams import SingleStreamManager, VirtualFileObject


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

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.dir.cleanup()


class TestStreamBlock(TestCase):
    def test_position(self):
        self.fail()

    def test_load_meta(self):
        self.fail()


class TestBaseStream(TestCase):
    def test_identity(self):
        self.fail()

    def test_manager(self):
        self.fail()

    def test_data(self):
        self.fail()

    def test_load_meta(self):
        self.fail()

    def test_meta_unpack(self):
        self.fail()

    def test_length(self):
        self.fail()

    def test_changed(self):
        self.fail()

    def test_save(self):
        self.fail()

    def test_next(self):
        self.fail()

    def test_previous(self):
        self.fail()

    def test_extend(self):
        self.fail()

    def test_push(self):
        self.fail()

    def test_pop(self):
        self.fail()

    def test_truncate(self):
        self.fail()

    def test_wind(self):
        self.fail()

    def test_close(self):
        self.fail()


class TestInternalStream(TestCase):
    def test_close(self):
        self.fail()


class TestDataStream(TestCase):
    def test_close(self):
        self.fail()


class TestVirtualFileObject(TestCase):
    def test__close(self):
        self.fail()

    def test__flush(self):
        self.fail()

    def test__readinto(self):
        self.fail()

    def test__seek(self):
        self.fail()

    def test__truncate(self):
        self.fail()

    def test__write(self):
        self.fail()


class TestRegistry(TestCase):
    def test_tree(self):
        self.fail()

    def test_close(self):
        self.fail()

    def test__init_tree(self):
        self.fail()

    def test__checkpoint(self):
        self.fail()


class TestStreamRegistry(TestCase):
    def test__init_tree(self):
        self.fail()

    def test_register(self):
        self.fail()

    def test_unregister(self):
        self.fail()

    def test_update(self):
        self.fail()

    def test_search(self):
        self.fail()


class TestStreamManager(TestCase):
    def test_closed(self):
        self.fail()

    def test_created(self):
        self.fail()

    def test_close(self):
        self.fail()

    def test_save_meta(self):
        self.fail()

    def test_meta(self):
        self.fail()

    def test_special_block(self):
        self.fail()

    def test_new_block(self):
        self.fail()

    def test_load_block(self):
        self.fail()

    def test_save_block(self):
        self.fail()

    def test_special_stream(self):
        self.fail()

    def test__setup(self):
        self.fail()

    def test__open(self):
        self.fail()

    def test__close(self):
        self.fail()

    def test_recycle(self):
        self.fail()

    def test_reuse(self):
        self.fail()


class TestSingleStreamManager(BaseArchiveTestCase):
    def test_recycle(self):
        self.fail()

    def test_reuse(self):
        self.fail()

    def test_run(self):
        try:
            data = bytes(os.urandom(2**20))
            mgr = SingleStreamManager(os.path.join(self.home, "test.ar7"), self.secret)
            stream = mgr.special_stream(SingleStreamManager.STREAM_DATA)
            fileobj = VirtualFileObject(stream, "test", "wb+")
            fileobj.write(data)
            fileobj.close()
            mgr.close()
            del mgr

            mgr = SingleStreamManager(os.path.join(self.home, "test.ar7"), self.secret)
            fileobj = VirtualFileObject(mgr.special_stream(SingleStreamManager.STREAM_DATA), "test")
            data2 = fileobj.read()

            self.assertEqual(
                 hashlib.sha1(data).digest(),
                 hashlib.sha1(data2).digest()
            )
            fileobj.close()
            mgr.close()
        except Exception as e:
            self.fail(e)


class TestFixedMultiStreamManager(TestCase):
    def test_recycle(self):
        self.fail()

    def test_reuse(self):
        self.fail()


class TestDynamicMultiStreamManager(TestCase):
    def test__close(self):
        self.fail()

    def test_new_stream(self):
        self.fail()

    def test_open_stream(self):
        self.fail()

    def test_close_stream(self):
        self.fail()

    def test_del_stream(self):
        self.fail()
