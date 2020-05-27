#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import os
from tempfile import TemporaryDirectory
from unittest import TestCase

from bplustree.const import TreeConf, OTHERS_BYTES
from bplustree.memory import open_file_in_dir, write_to_file, read_from_file, FileMemory
from bplustree.serializer import UUIDSerializer

# FIXME: Write the rest of the memory tests


def tree_conf(page_size, order, key_size, value_size, serializer=None):
    return TreeConf(
        page_size, order, key_size, value_size, OTHERS_BYTES,
        serializer or UUIDSerializer()
    )


class Test(TestCase):
    def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.filename = os.path.join(self.dir.name, "test.db")
        self.data = os.urandom(2048)

    def tearDown(self) -> None:
        self.dir.cleanup()

    def test_open_file_in_dir(self):
        try:
            fileobj, _ = open_file_in_dir(self.filename)
            fileobj.write(self.data)
            fileobj.close()
            fileobj, _ = open_file_in_dir(self.filename)
            data = fileobj.read()
            fileobj.close()
            self.assertEqual(self.data, data)
        except Exception as e:
            self.fail(e)

    def test_write_to_file(self):
        try:
            fileobj = open(self.filename, "xb+")
            write_to_file(fileobj, self.data)
            fileobj.close()
            fileobj = open(self.filename, "rb+")
            data = fileobj.read()
            fileobj.close()
            self.assertEqual(self.data, data)
        except Exception as e:
            self.fail(e)

    def test_read_from_file(self):
        try:
            fileobj = open(self.filename, "xb+")
            fileobj.write(self.data)
            fileobj.close()
            fileobj = open(self.filename, "rb+")
            data = read_from_file(fileobj, 0, 2048)
            fileobj.close()
            self.assertEqual(self.data, data)
        except Exception as e:
            self.fail(e)


class TestFakeCache(TestCase):
    def test_get(self):
        # Skip testing of fake cache
        pass

    def test_clear(self):
        # Skip testing of fake cache
        pass


class TestFileMemory(TestCase):
    def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.conf = tree_conf(512, 10, 16, 32)
        self.database = os.path.join(self.dir.name, "database.db")
        self.wal = os.path.join(self.dir.name, "wal.db")
        self.memory = FileMemory(self.database, self.wal, self.conf)
        self.data = os.urandom(2048)

    def tearDown(self) -> None:
        if not self.database.closed:
            self.database.close()
        if not self.wal.closed:
            self.wal.close()
        self.dir.cleanup()

    def test_get_node(self):
        try:
            pass
        except Exception as e:
            self.fail()

    def test_set_node(self):
        self.fail()

    def test_del_node(self):
        self.fail()

    def test_del_page(self):
        self.fail()

    def test_read_transaction(self):
        self.fail()

    def test_write_transaction(self):
        self.fail()

    def test_next_available_page(self):
        self.fail()

    def test__traverse_free_list(self):
        self.fail()

    def test__insert_in_freelist(self):
        self.fail()

    def test__pop_from_freelist(self):
        self.fail()

    def test_get_metadata(self):
        self.fail()

    def test_set_metadata(self):
        self.fail()

    def test_close(self):
        self.fail()

    def test_perform_checkpoint(self):
        self.fail()

    def test__read_page(self):
        self.fail()

    def test__write_page_in_tree(self):
        self.fail()


class TestFrameType(TestCase):
    pass


class TestWAL(TestCase):
    def test_checkpoint(self):
        self.fail()

    def test__create_header(self):
        self.fail()

    def test__load_wal(self):
        self.fail()

    def test__load_next_frame(self):
        self.fail()

    def test__index_frame(self):
        self.fail()

    def test__add_frame(self):
        self.fail()

    def test_get_page(self):
        self.fail()

    def test_set_page(self):
        self.fail()

    def test_commit(self):
        self.fail()

    def test_rollback(self):
        self.fail()
