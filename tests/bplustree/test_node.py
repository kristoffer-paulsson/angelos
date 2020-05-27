#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import os
import uuid
from unittest import TestCase

from bplustree.const import TreeConf, OTHERS_BYTES
from bplustree.entry import Record, Reference, OpaqueData
from bplustree.serializer import UUIDSerializer
from bplustree.node import Node, RecordNode, LonelyRootNode, LeafNode, ReferenceNode, RootNode, InternalNode, \
    OverflowNode, FreelistNode


def tree_conf(page_size, order, key_size, value_size, serializer=None):
    return TreeConf(
        page_size, order, key_size, value_size, OTHERS_BYTES,
        serializer or UUIDSerializer()
    )


class TestNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = Node(self.conf)
        self.small_rec = Record(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Record(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            parent = self.node
            node = Node(self.conf, parent=parent)
            data = node.dump()
            new_node = Node(self.conf, bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            parent = self.node
            node = Node(self.conf, parent=parent)
            data = node.dump()
            new_node = Node(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 2)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            with self.assertRaises(TypeError):
                node.remove_entry(self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            with self.assertRaises(TypeError):
                node.get_entry(self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        # Only applicable on non-abstract class
        pass


class TestRecordNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = RecordNode(self.conf)
        self.small_rec = Record(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Record(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            parent = self.node
            node = RecordNode(self.conf, parent=parent)
            data = node.dump()
            new_node = RecordNode(self.conf, bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            parent = self.node
            node = RecordNode(self.conf, parent=parent)
            data = node.dump()
            new_node = RecordNode(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 2)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            node.remove_entry(self.small_rec.key)
            with self.assertRaises(ValueError):
                node.get_entry(self.small_rec.key)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            entry = node.get_entry(self.small_rec.key)
            self.assertIs(entry, self.small_rec)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        pass


class TestLonelyRootNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = LonelyRootNode(self.conf)
        self.small_rec = Record(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Record(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            parent = self.node
            node = LonelyRootNode(self.conf, parent=parent)
            data = node.dump()
            new_node = LonelyRootNode(self.conf, bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            parent = self.node
            node = LonelyRootNode(self.conf, parent=parent)
            data = node.dump()
            new_node = LonelyRootNode(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertTrue(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 2)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            node.remove_entry(self.small_rec.key)
            with self.assertRaises(ValueError):
                node.get_entry(self.small_rec.key)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            entry = node.get_entry(self.small_rec.key)
            self.assertIs(entry, self.small_rec)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        pass

    ####

    def test_convert_to_leaf(self):
        pass


class TestLeafNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = LeafNode(self.conf)
        self.small_rec = Record(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Record(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            parent = self.node
            node = LeafNode(self.conf, parent=parent)
            data = node.dump()
            new_node = LeafNode(self.conf, bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            parent = self.node
            node = LeafNode(self.conf, parent=parent)
            data = node.dump()
            new_node = LeafNode(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertTrue(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 2)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            node.remove_entry(self.small_rec.key)
            with self.assertRaises(ValueError):
                node.get_entry(self.small_rec.key)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            entry = node.get_entry(self.small_rec.key)
            self.assertIs(entry, self.small_rec)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        pass


class TestReferenceNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = ReferenceNode(self.conf)
        self.small_rec = Reference(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Reference(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            parent = self.node
            node = ReferenceNode(self.conf, parent=parent)
            data = node.dump()
            new_node = ReferenceNode(self.conf, bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            parent = self.node
            node = ReferenceNode(self.conf, parent=parent)
            data = node.dump()
            new_node = ReferenceNode(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    # def test_num_children(self):
    # Overriden, look at the end

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    # def test_insert_entry(self):
    # Overriden, look at the end

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            node.remove_entry(self.small_rec.key)
            with self.assertRaises(ValueError):
                node.get_entry(self.small_rec.key)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            entry = node.get_entry(self.small_rec.key)
            self.assertIs(entry, self.small_rec)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        pass

    ####

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 3)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)


class TestRootNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = RootNode(self.conf)
        self.small_rec = Reference(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Reference(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            parent = self.node
            node = RootNode(self.conf, parent=parent)
            data = node.dump()
            new_node = RootNode(self.conf, bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            parent = self.node
            node = RootNode(self.conf, parent=parent)
            data = node.dump()
            new_node = RootNode(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertTrue(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 3)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            node.remove_entry(self.small_rec.key)
            with self.assertRaises(ValueError):
                node.get_entry(self.small_rec.key)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            entry = node.get_entry(self.small_rec.key)
            self.assertIs(entry, self.small_rec)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        pass

    ####

    def test_convert_to_internal(self):
        pass


class TestInternalNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = InternalNode(self.conf)
        self.small_rec = Reference(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Reference(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            parent = self.node
            node = InternalNode(self.conf, parent=parent)
            data = node.dump()
            new_node = InternalNode(self.conf, bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            parent = self.node
            node = InternalNode(self.conf, parent=parent)
            data = node.dump()
            new_node = InternalNode(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertTrue(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 3)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            node.remove_entry(self.small_rec.key)
            with self.assertRaises(ValueError):
                node.get_entry(self.small_rec.key)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            entry = node.get_entry(self.small_rec.key)
            self.assertIs(entry, self.small_rec)
            entry = node.get_entry(self.big_rec.key)
            self.assertIs(entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        pass


class TestOverflowNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = OverflowNode(self.conf)
        self.small_rec = OpaqueData(self.conf, os.urandom(32))
        self.big_rec = OpaqueData(self.conf, os.urandom(32))

    def test_load(self):
        try:
            node = self.node
            data = node.dump()
            # TODO:
            #  Redesign classes / refactor
            # new_node = OverflowNode(self.conf, bytes(data))
            # self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            node = self.node
            data = node.dump()
            new_node = OverflowNode(self.conf)
            # new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertTrue(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            # TODO:
            #  Attribute error, smallest_key isn't compatible with OpaqueData
            #  Redesign classes / refactor
            # node.smallest_key
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.big_rec)
            # TODO:
            #  Attribute error, biggest_key isn't compatible with OpaqueData
            #  Redesign classes / refactor
            # node.biggest_key
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            self.assertIs(node.num_children, 1)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            # TODO:
            #  Attribute error, remove_entry() isn't compatible with OpaqueData
            #  Redesign classes / refactor
            # node.remove_entry(self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            # TODO:
            #  Attribute error, get_entry() isn't compatible with OpaqueData
            #  Redesign classes / refactor
            # entry = node.get_entry(self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        # Only applicable on non-abstract class
        pass


class TestFreelistNode(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.node = FreelistNode(self.conf)
        self.small_rec = Record(self.conf, uuid.UUID(int=1), os.urandom(32))
        self.big_rec = Record(self.conf, uuid.UUID(int=2), os.urandom(32))

    def test_load(self):
        try:
            # TODO:
            #  Attribute error, something isn't compatible with FreelistNode
            #  Redesign classes / refactor
            node = self.node
            data = node.dump()
            new_node = FreelistNode(self.conf)
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            node = self.node
            data = node.dump()
            new_node = FreelistNode(self.conf)
            new_node.load(bytes(data))
            self.assertEqual(node, new_node)
        except Exception as e:
            self.fail(e)

    def test_max_payload(self):
        try:
            node = self.node
            self.assertIsInstance(node.max_payload, int)
        except Exception as e:
            self.fail(e)

    def test_can_add_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_add_entry)
        except Exception as e:
            self.fail(e)

    def test_can_delete_entry(self):
        try:
            node = self.node
            self.assertFalse(node.can_delete_entry)
        except Exception as e:
            self.fail(e)

    def test_smallest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_key, self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test_smallest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.smallest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.smallest_entry, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_biggest_key(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_key
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_key, self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_biggest_entry(self):
        try:
            node = self.node
            with self.assertRaises(IndexError):
                node.biggest_entry
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.biggest_entry, self.big_rec)
        except Exception as e:
            self.fail(e)

    def test_num_children(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            self.assertIs(node.num_children, 2)
        except Exception as e:
            self.fail(e)

    def test_pop_smallest(self):
        try:
            node = self.node
            self.assertIs(node.num_children, 0)
            with self.assertRaises(IndexError):
                node.pop_smallest()
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            popped = node.pop_smallest()
            self.assertIs(popped, self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_insert_entry_at_the_end(self):
        try:
            node = self.node
            node.insert_entry_at_the_end(self.small_rec)
        except Exception as e:
            self.fail(e)

    def test_remove_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            # TODO:
            #  Attribute error, remove_entry() and get_entry() isn't compatible with FreelistNode
            #  Redesign classes / refactor
            # node.remove_entry(self.small_rec.key)
            # entry = node.get_entry(self.big_rec.key)
        except Exception as e:
            self.fail(e)

    def test_get_entry(self):
        try:
            node = self.node
            node.insert_entry(self.small_rec)
            node.insert_entry(self.big_rec)
            # TODO:
            #  Attribute error, remove_entry() and get_entry() isn't compatible with FreelistNode
            #  Redesign classes / refactor
            # entry = node.get_entry(self.small_rec.key)
        except Exception as e:
            self.fail(e)

    def test__find_entry_index(self):
        pass

    def test_split_entries(self):
        pass

    def test_from_page_data(self):
        pass
