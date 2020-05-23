#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
from unittest import TestCase


class Test(TestCase):
    def test_open_file_in_dir(self):
        self.fail()

    def test_write_to_file(self):
        self.fail()

    def test_read_from_file(self):
        self.fail()


class TestFakeCache(TestCase):
    def test_get(self):
        self.fail()

    def test_clear(self):
        self.fail()


class TestFileMemory(TestCase):
    def test_get_node(self):
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
