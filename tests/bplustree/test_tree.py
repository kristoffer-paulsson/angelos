#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import os
import random
import uuid
from tempfile import TemporaryDirectory
from unittest import TestCase

from bplustree.serializer import UUIDSerializer
from bplustree.tree import SingleItemTree, MultiItemTree


class TestBPlusTree(TestCase):
    def test_close(self):
        self.fail()

    def test_checkpoint(self):
        self.fail()

    def test_insert(self):
        self.fail()

    def test_batch_insert(self):
        self.fail()

    def test_get(self):
        self.fail()

    def test_remove(self):
        self.fail()

    def test_items(self):
        self.fail()

    def test_values(self):
        self.fail()

    def test__initialize_empty_tree(self):
        self.fail()

    def test__create_partials(self):
        self.fail()

    def test__root_node(self):
        self.fail()

    def test__left_record_node(self):
        self.fail()

    def test__iter_slice(self):
        self.fail()

    def test__search_in_tree(self):
        self.fail()

    def test__split_leaf(self):
        self.fail()

    def test__split_parent(self):
        self.fail()

    def test__create_new_root(self):
        self.fail()

    def test__create_overflow(self):
        self.fail()

    def test__traverse_overflow(self):
        self.fail()

    def test__read_from_overflow(self):
        self.fail()

    def test__delete_overflow(self):
        self.fail()

    def test__get_value_from_record(self):
        self.fail()

    def test__multi_value_update(self):
        self.fail()


class TestBaseTree(TestCase):
    def test__conf(self):
        self.fail()

    def test_close(self):
        self.fail()

    def test_checkpoint(self):
        self.fail()

    def test_insert(self):
        self.fail()

    def test_update(self):
        self.fail()

    def test_batch_insert(self):
        self.fail()

    def test_get(self):
        self.fail()

    def test_delete(self):
        self.fail()

    def test_items(self):
        self.fail()

    def test_values(self):
        self.fail()

    def test__initialize_empty_tree(self):
        self.fail()

    def test__create_partials(self):
        self.fail()

    def test__root_node(self):
        self.fail()

    def test__left_record_node(self):
        self.fail()

    def test__iter_slice(self):
        self.fail()

    def test__search_in_tree(self):
        self.fail()

    def test__split_leaf(self):
        self.fail()

    def test__split_parent(self):
        self.fail()

    def test__create_new_root(self):
        self.fail()

    def test__get_value_from_record(self):
        self.fail()


class TestSingleItemTree(TestCase):
    def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.db_file = os.path.join(self.dir.name, "database.db")
        self.db_wal = os.path.join(self.dir.name, "wal.db")
        self.fd_file = open(self.db_file, "xb+")
        self.fd_wal = open(self.db_wal, "xb+")
        self.tree = SingleItemTree(
            self.fd_file, self.fd_wal, page_size=1024,
            key_size=16, value_size=24, serializer=UUIDSerializer()
        )
        self.data = {uuid.uuid4(): os.urandom(24) for _ in range(100)}

    def tearDown(self) -> None:
        self.tree.close()
        if not self.fd_file.closed:
            self.fd_file.close()
        if not self.fd_wal.closed:
            self.fd_wal.close()
        self.dir.cleanup()

    def test__conf(self):
        # Skip protected method
        pass

    def test_insert(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            random.shuffle(keys)
            for key in keys:
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)

    def test_update(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            for key in keys[0:50]:
                data = os.urandom(24)
                self.data[key] = data
                self.tree.update(key, data)
            self.tree.checkpoint()

            random.shuffle(keys)
            for key in keys:
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)

    def test_batch_insert(self):
        self.fail()

    def test_get(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            random.shuffle(keys)
            for key in keys:
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)

    def test_delete(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            for key in keys[0:50]:
                self.tree.delete(key)
            self.tree.checkpoint()

            for key in keys[0:50]:
                self.assertEqual(self.tree.get(key), None)

            for key in keys[50:]:
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)

    def test__get_value_from_record(self):
        # Skip protected method
        pass


class TestMultiItemIterator(TestCase):
    pass


class TestMultiItemTree(TestCase):
    def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.db_file = os.path.join(self.dir.name, "database.db")
        self.db_wal = os.path.join(self.dir.name, "wal.db")
        self.fd_file = open(self.db_file, "xb+")
        self.fd_wal = open(self.db_wal, "xb+")
        self.tree = MultiItemTree(
            self.fd_file, self.fd_wal, page_size=1024,
            key_size=16, value_size=16, serializer=UUIDSerializer()
        )
        self.data = dict()
        keys = [uuid.uuid4() for _ in range(100)]
        shuffled = keys
        for key in keys:
            random.shuffle(shuffled)
            self.data[key] = list()
            for item in shuffled[:random.randrange(1, 99)]:
                self.data[key].append(item)

    def tearDown(self) -> None:
        self.tree.close()
        if not self.fd_file.closed:
            self.fd_file.close()
        if not self.fd_wal.closed:
            self.fd_wal.close()
        self.dir.cleanup()

    def test__conf(self):
        # Skip protected method
        pass

    def test_insert(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            random.shuffle(keys)
            for key in keys:
                self.assertEqual([uuid.UUID(bytes=value) for value in self.tree.get(key)], self.data[key])
        except Exception as e:
            self.fail(e)

    def test_update(self):
        # TODO: Things to improve
        #   Write detailed tests for delete filters
        #   and insertion filters and have them verified
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            random.shuffle(keys)
            for key in keys:
                self.tree.update(key, keys[:random.randrange(1, 99)], set(keys[:random.randrange(1, 99)]))
        except Exception as e:
            self.fail(e)

    def test_batch_insert(self):
        self.fail()

    def test_get(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            random.shuffle(keys)
            for key in keys:
                self.assertEqual([uuid.UUID(bytes=value) for value in self.tree.get(key)], self.data[key])
        except Exception as e:
            self.fail(e)

    def test_delete(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            for key in keys[0:50]:
                self.tree.delete(key)
            self.tree.checkpoint()

            for key in keys[0:50]:
                self.assertEqual(self.tree.get(key), list())

            for key in keys[50:]:
                self.assertEqual([uuid.UUID(bytes=value) for value in self.tree.get(key)], self.data[key])
        except Exception as e:
            self.fail(e)

    def test__create_overflow(self):
        # Skip protected method
        pass

    def test__traverse_overflow(self):
        # Skip protected method
        pass

    def test__read_from_overflow(self):
        # Skip protected method
        pass

    def test__iterate_from_overflow(self):
        # Skip protected method
        pass

    def test__add_overflow(self):
        # Skip protected method
        pass

    def test__update_overflow(self):
        # Skip protected method
        pass

    def test__delete_overflow(self):
        # Skip protected method
        pass

    def test__get_value_from_record(self):
        # Skip protected method
        pass

    def test_traverse(self):
        try:
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])
            self.tree.checkpoint()

            random.shuffle(keys)
            for key in keys:
                for item in self.tree.traverse(key):
                    self.assertIn(item, self.data[key])
        except Exception as e:
            self.fail(e)

    def test__iterate_overflow(self):
        # Skip protected method
        pass
