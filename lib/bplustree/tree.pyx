# cython: language_level=3
#
# Copyright (c) 2017 by Nicolas Le Manchet
# Copyright (c) 2020 by Kristoffer Paulsson
# This file is distributed under the terms of the MIT license.
#
import functools
import io
import collections
from abc import abstractmethod, ABC
from functools import partial
from typing import Optional, Union, Iterator, Iterable, Generator

from bplustree.utils import pairwise, iter_slice
from bplustree.const import TreeConf, ENDIAN, OTHERS_BYTES
from bplustree.entry import Record, Reference, OpaqueData
from bplustree.memory import FileMemory
from bplustree.node import (
    Node, LonelyRootNode, RootNode, InternalNode, LeafNode, OverflowNode
)
from bplustree.serializer import Serializer, IntSerializer, UUIDSerializer


class BPlusTree:
    __slots__ = ['_tree_conf', '_mem', '_root_node_page',
                 '_is_open', 'LonelyRootNode', 'RootNode', 'InternalNode',
                 'LeafNode', 'OverflowNode', 'Record', 'Reference']

    # ######################### Public API ################################

    def __init__(self, file_db: io.FileIO, file_journal: io.FileIO, page_size: int = 4096, order: int = 100,
                 key_size: int = 8, value_size: int = 32, cache_size: int = 64,
                 serializer: Optional[Serializer] = None):
        self._tree_conf = TreeConf(
            page_size, order, key_size, value_size,
            serializer or IntSerializer()
        )
        self._create_partials()
        self._mem = FileMemory(file_db, file_journal, self._tree_conf, cache_size=cache_size)
        try:
            metadata = self._mem.get_metadata()
        except ValueError:
            self._initialize_empty_tree()
        else:
            self._root_node_page, self._tree_conf = metadata
        self._is_open = True

    def close(self):
        with self._mem.write_transaction:
            if not self._is_open:
                raise OSError("Tree is already closed")
                return

            self._mem.close()
            self._is_open = False

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def checkpoint(self):
        with self._mem.write_transaction:
            self._mem.perform_checkpoint(reopen_wal=True)

    def insert(self, key, value: bytes, replace=False):
        """Insert a value in the tree.

        :param key: The key at which the value will be recorded, must be of the
                    same type used by the Serializer
        :param value: The value to record in bytes
        :param replace: If True, already existing value will be overridden,
                        otherwise a ValueError is raised.
        """
        if not isinstance(value, bytes):
            ValueError('Values must be bytes objects')

        with self._mem.write_transaction:
            node = self._search_in_tree(key, self._root_node)

            # Check if a record with the key already exists
            try:
                existing_record = node.get_entry(key)
            except ValueError:
                pass
            else:
                if not replace:
                    raise ValueError('Key {} already exists'.format(key))

                if existing_record.overflow_page:
                    self._delete_overflow(existing_record.overflow_page)

                if len(value) <= self._tree_conf.value_size:
                    existing_record.value = value
                    existing_record.overflow_page = None
                else:
                    existing_record.value = None
                    existing_record.overflow_page = self._create_overflow(
                        value
                    )
                self._mem.set_node(node)
                return

            if len(value) <= self._tree_conf.value_size:
                record = self.Record(key, value=value)
            else:
                # Record values exceeding the max value_size must be placed
                # into overflow pages
                first_overflow_page = self._create_overflow(value)
                record = self.Record(key, value=None,
                                     overflow_page=first_overflow_page)

            if node.can_add_entry:
                node.insert_entry(record)
                self._mem.set_node(node)
            else:
                node.insert_entry(record)
                self._split_leaf(node)

    def batch_insert(self, iterable: Iterable):
        """Insert many elements in the tree at once.

        The iterable object must yield tuples (key, value) in ascending order.
        All keys to insert must be bigger than all keys currently in the tree.
        All inserts happen in a single transaction. This is way faster than
        manually inserting in a loop.
        """
        node = None
        with self._mem.write_transaction:

            for key, value in iterable:

                if node is None:
                    node = self._search_in_tree(key, self._root_node)

                try:
                    biggest_entry = node.biggest_entry
                except IndexError:
                    biggest_entry = None
                if biggest_entry and key <= biggest_entry.key:
                    raise ValueError('Keys to batch insert must be sorted and '
                                     'bigger than keys currently in the tree')

                if len(value) <= self._tree_conf.value_size:
                    record = self.Record(key, value=value)
                else:
                    # Record values exceeding the max value_size must be placed
                    # into overflow pages
                    first_overflow_page = self._create_overflow(value)
                    record = self.Record(key, value=None, overflow_page=first_overflow_page)

                if node.can_add_entry:
                    node.insert_entry_at_the_end(record)
                else:
                    node.insert_entry_at_the_end(record)
                    self._split_leaf(node)
                    node = None

            if node is not None:
                self._mem.set_node(node)

    def get(self, key, default=None) -> bytes:
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                return default
            else:
                rv = self._get_value_from_record(record)
                assert isinstance(rv, bytes)
                return rv

    def remove(self, key, default=None) -> bytes:
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                return default
            else:
                rv = self._get_value_from_record(record)
                if node.overflow_page is not None:
                    self._delete_overflow(node.overflow_page)
                self._mem.del_node(node)
                assert isinstance(rv, bytes)
                return rv

    def __contains__(self, item):
        with self._mem.read_transaction:
            o = object()
            return False if self.get(item, default=o) is o else True

    def __setitem__(self, key, value):
        self.insert(key, value, replace=True)

    def __getitem__(self, item):
        with self._mem.read_transaction:

            if isinstance(item, slice):
                # Returning a dict is the most sensible thing to do
                # as a method cannot return a sometimes a generator
                # and sometimes a normal value
                rv = dict()
                for record in self._iter_slice(item):
                    rv[record.key] = self._get_value_from_record(record)
                return rv

            else:
                rv = self.get(item)
                if rv is None:
                    raise KeyError(item)
                return rv

    def __len__(self):
        with self._mem.read_transaction:
            node = self._left_record_node
            rv = 0
            while True:
                rv += len(node.entries)
                if not node.next_page:
                    return rv
                node = self._mem.get_node(node.next_page)

    def __length_hint__(self):
        with self._mem.read_transaction:
            node = self._root_node
            if isinstance(node, LonelyRootNode):
                # Assume that the lonely root node is half full
                return node.max_children // 2
            # Assume that there are no holes in pages
            last_page = self._mem.last_page
            # Assume that 70% of nodes in a tree carry values
            num_leaf_nodes = int(last_page * 0.70)
            # Assume that every leaf node is half full
            num_records_per_leaf_node = int(
                (node.max_children + node.min_children) / 2
            )
            return num_leaf_nodes * num_records_per_leaf_node

    def __iter__(self, slice_: Optional[slice] = None):
        if not slice_:
            slice_ = slice(None)
        with self._mem.read_transaction:
            for record in self._iter_slice(slice_):
                yield record.key

    keys = __iter__

    def items(self, slice_: Optional[slice] = None) -> Iterator[tuple]:
        if not slice_:
            slice_ = slice(None)
        with self._mem.read_transaction:
            for record in self._iter_slice(slice_):
                yield record.key, self._get_value_from_record(record)

    def values(self, slice_: Optional[slice] = None) -> Iterator[bytes]:
        if not slice_:
            slice_ = slice(None)
        with self._mem.read_transaction:
            for record in self._iter_slice(slice_):
                yield self._get_value_from_record(record)

    def __bool__(self):
        with self._mem.read_transaction:
            for _ in self:
                return True
            return False

    def __repr__(self):
        return '<BPlusTree: {} {}>'.format(self.__filename, self._tree_conf)


    def _initialize_empty_tree(self):
        self._root_node_page = self._mem.next_available_page
        with self._mem.write_transaction:
            self._mem.set_node(self.LonelyRootNode(page=self._root_node_page))
        self._mem.set_metadata(self._root_node_page, self._tree_conf)

    def _create_partials(self):
        self.LonelyRootNode = partial(LonelyRootNode, self._tree_conf)
        self.RootNode = partial(RootNode, self._tree_conf)
        self.InternalNode = partial(InternalNode, self._tree_conf)
        self.LeafNode = partial(LeafNode, self._tree_conf)
        self.OverflowNode = partial(OverflowNode, self._tree_conf)
        self.Record = partial(Record, self._tree_conf)
        self.Reference = partial(Reference, self._tree_conf)

    @property
    def _root_node(self) -> Union['LonelyRootNode', 'RootNode']:
        root_node = self._mem.get_node(self._root_node_page)
        assert isinstance(root_node, (LonelyRootNode, RootNode))
        return root_node

    @property
    def _left_record_node(self) -> Union['LonelyRootNode', 'LeafNode']:
        node = self._root_node
        while not isinstance(node, (LonelyRootNode, LeafNode)):
            node = self._mem.get_node(node.smallest_entry.before)
        return node

    def _iter_slice(self, slice_: slice) -> Iterator[Record]:
        if slice_.step is not None:
            raise ValueError('Cannot iterate with a custom step')

        if (slice_.start is not None and slice_.stop is not None and
                slice_.start >= slice_.stop):
            raise ValueError('Cannot iterate backwards')

        if slice_.start is None:
            node = self._left_record_node
        else:
            node = self._search_in_tree(slice_.start, self._root_node)

        while True:
            for entry in node.entries:
                if slice_.start is not None and entry.key < slice_.start:
                    continue

                if slice_.stop is not None and entry.key >= slice_.stop:
                    return

                yield entry

            if node.next_page:
                node = self._mem.get_node(node.next_page)
            else:
                return

    def _search_in_tree(self, key, node) -> 'Node':
        if isinstance(node, (LonelyRootNode, LeafNode)):
            return node

        page = None

        if key < node.smallest_key:
            page = node.smallest_entry.before

        elif node.biggest_key <= key:
            page = node.biggest_entry.after

        else:
            for ref_a, ref_b in pairwise(node.entries):
                if ref_a.key <= key < ref_b.key:
                    page = ref_a.after
                    break

        assert page is not None

        child_node = self._mem.get_node(page)
        child_node.parent = node
        return self._search_in_tree(key, child_node)

    def _split_leaf(self, old_node: 'Node'):
        """Split a leaf Node to allow the tree to grow."""
        parent = old_node.parent
        new_node = self.LeafNode(page=self._mem.next_available_page,
                                 next_page=old_node.next_page)
        new_entries = old_node.split_entries()
        new_node.entries = new_entries
        ref = self.Reference(new_node.smallest_key,
                             old_node.page, new_node.page)

        if isinstance(old_node, LonelyRootNode):
            # Convert the LonelyRoot into a Leaf
            old_node = old_node.convert_to_leaf()
            self._create_new_root(ref)
        elif parent.can_add_entry:
            parent.insert_entry(ref)
            self._mem.set_node(parent)
        else:
            parent.insert_entry(ref)
            self._split_parent(parent)

        old_node.next_page = new_node.page

        self._mem.set_node(old_node)
        self._mem.set_node(new_node)

    def _split_parent(self, old_node: Node):
        parent = old_node.parent
        new_node = self.InternalNode(page=self._mem.next_available_page)
        new_entries = old_node.split_entries()
        new_node.entries = new_entries

        ref = new_node.pop_smallest()
        ref.before = old_node.page
        ref.after = new_node.page

        if isinstance(old_node, RootNode):
            # Convert the Root into an Internal
            old_node = old_node.convert_to_internal()
            self._create_new_root(ref)
        elif parent.can_add_entry:
            parent.insert_entry(ref)
            self._mem.set_node(parent)
        else:
            parent.insert_entry(ref)
            self._split_parent(parent)

        self._mem.set_node(old_node)
        self._mem.set_node(new_node)

    def _create_new_root(self, reference: Reference):
        new_root = self.RootNode(page=self._mem.next_available_page)
        new_root.insert_entry(reference)
        self._root_node_page = new_root.page
        self._mem.set_metadata(self._root_node_page, self._tree_conf)
        self._mem.set_node(new_root)

    def _create_overflow(self, value: bytes) -> int:
        first_overflow_page = self._mem.next_available_page
        next_overflow_page = first_overflow_page

        iterator = iter_slice(value, self.OverflowNode().max_payload)
        for slice_value, is_last in iterator:
            current_overflow_page = next_overflow_page

            if is_last:
                next_overflow_page = None
            else:
                next_overflow_page = self._mem.next_available_page

            overflow_node = self.OverflowNode(
                page=current_overflow_page, next_page=next_overflow_page
            )
            overflow_node.insert_entry_at_the_end(OpaqueData(data=slice_value))
            self._mem.set_node(overflow_node)

        return first_overflow_page

    def _traverse_overflow(self, first_overflow_page: int):
        """Yield all Nodes of an overflow chain."""
        next_overflow_page = first_overflow_page
        while True:
            overflow_node = self._mem.get_node(next_overflow_page)
            yield overflow_node

            next_overflow_page = overflow_node.next_page
            if next_overflow_page is None:
                break

    def _read_from_overflow(self, first_overflow_page: int) -> bytes:
        """Collect all values of an overflow chain."""
        rv = bytearray()
        for overflow_node in self._traverse_overflow(first_overflow_page):
            rv.extend(overflow_node.smallest_entry.data)

        return bytes(rv)

    def _delete_overflow(self, first_overflow_page: int):
        """Delete all Nodes in an overflow chain."""
        for overflow_node in self._traverse_overflow(first_overflow_page):
            self._mem.del_node(overflow_node)

    def _get_value_from_record(self, record: Record) -> bytes:
        if record.value is not None:
            return record.value

        return self._read_from_overflow(record.overflow_page)


class BaseTree(ABC):
    """Base of a BPlusTree."""

    __slots__ = ['_tree_conf', '_mem', '_root_node_page',
                 '_is_open', 'LonelyRootNode', 'RootNode', 'InternalNode',
                 'LeafNode', 'OverflowNode', 'Record', 'Reference']

    def __init__(self, file_db: io.FileIO, file_journal: io.FileIO, page_size: int = 4096,
                 key_size: int = 8, value_size: int = 32, cache_size: int = 64,
                 serializer: Optional[Serializer] = None):
        self._tree_conf = self._conf(page_size, key_size, value_size, serializer)
        self._create_partials()
        self._mem = FileMemory(file_db, file_journal, self._tree_conf, cache_size=cache_size)
        try:
            metadata = self._mem.get_metadata()
        except ValueError:
            self._initialize_empty_tree()
        else:
            self._root_node_page, self._tree_conf = metadata
        self._is_open = True

    @abstractmethod
    def _conf(
        self, page_size: int, key_size: int, value_size: int,
        serializer: Optional[Serializer] = None
    ) -> TreeConf:
        pass

    def close(self):
        with self._mem.write_transaction:
            if not self._is_open:
                raise OSError("Tree is already closed")
                return

            self._mem.close()
            self._is_open = False

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def checkpoint(self):
        with self._mem.write_transaction:
            self._mem.perform_checkpoint(reopen_wal=True)

    @abstractmethod
    def insert(self, key, value: Union[bytes, set, list]):
        pass

    @abstractmethod
    def update(self, key, value: Union[bytes, set, list]):
        pass

    @abstractmethod
    def batch_insert(self, iterable: Iterable):
        pass

    @abstractmethod
    def get(self, key, default=None) -> bytes:
        pass

    @abstractmethod
    def delete(self, key, default=None) -> bytes:
        pass

    def __contains__(self, item):
        with self._mem.read_transaction:
            o = object()
            return False if self.get(item, default=o) is o else True

    def __setitem__(self, key, value):
        self.insert(key, value, replace=True)

    def __getitem__(self, item):
        with self._mem.read_transaction:

            if isinstance(item, slice):
                # Returning a dict is the most sensible thing to do
                # as a method cannot return a sometimes a generator
                # and sometimes a normal value
                rv = dict()
                for record in self._iter_slice(item):
                    rv[record.key] = self._get_value_from_record(record)
                return rv

            else:
                rv = self.get(item)
                if rv is None:
                    raise KeyError(item)
                return rv

    def __len__(self):
        with self._mem.read_transaction:
            node = self._left_record_node
            rv = 0
            while True:
                rv += len(node.entries)
                if not node.next_page:
                    return rv
                node = self._mem.get_node(node.next_page)

    def __length_hint__(self):
        with self._mem.read_transaction:
            node = self._root_node
            if isinstance(node, LonelyRootNode):
                # Assume that the lonely root node is half full
                return node.max_children // 2
            # Assume that there are no holes in pages
            last_page = self._mem.last_page
            # Assume that 70% of nodes in a tree carry values
            num_leaf_nodes = int(last_page * 0.70)
            # Assume that every leaf node is half full
            num_records_per_leaf_node = int(
                (node.max_children + node.min_children) / 2
            )
            return num_leaf_nodes * num_records_per_leaf_node

    def __iter__(self, slice_: Optional[slice] = None):
        if not slice_:
            slice_ = slice(None)
        with self._mem.read_transaction:
            for record in self._iter_slice(slice_):
                yield record.key

    keys = __iter__

    def items(self, slice_: Optional[slice] = None) -> Iterator[tuple]:
        if not slice_:
            slice_ = slice(None)
        with self._mem.read_transaction:
            for record in self._iter_slice(slice_):
                yield record.key, self._get_value_from_record(record)

    def values(self, slice_: Optional[slice] = None) -> Iterator[bytes]:
        if not slice_:
            slice_ = slice(None)
        with self._mem.read_transaction:
            for record in self._iter_slice(slice_):
                yield self._get_value_from_record(record)

    def __bool__(self):
        with self._mem.read_transaction:
            for _ in self:
                return True
            return False

    def __repr__(self):
        return '<BPlusTree: {} {}>'.format(self.__filename, self._tree_conf)


    def _initialize_empty_tree(self):
        self._root_node_page = self._mem.next_available_page
        with self._mem.write_transaction:
            self._mem.set_node(self.LonelyRootNode(page=self._root_node_page))
        self._mem.set_metadata(self._root_node_page, self._tree_conf)

    def _create_partials(self):
        self.LonelyRootNode = partial(LonelyRootNode, self._tree_conf)
        self.RootNode = partial(RootNode, self._tree_conf)
        self.InternalNode = partial(InternalNode, self._tree_conf)
        self.LeafNode = partial(LeafNode, self._tree_conf)
        self.OverflowNode = partial(OverflowNode, self._tree_conf)
        self.Record = partial(Record, self._tree_conf)
        self.Reference = partial(Reference, self._tree_conf)

    @property
    def _root_node(self) -> Union['LonelyRootNode', 'RootNode']:
        root_node = self._mem.get_node(self._root_node_page)
        assert isinstance(root_node, (LonelyRootNode, RootNode))
        return root_node

    @property
    def _left_record_node(self) -> Union['LonelyRootNode', 'LeafNode']:
        node = self._root_node
        while not isinstance(node, (LonelyRootNode, LeafNode)):
            node = self._mem.get_node(node.smallest_entry.before)
        return node

    def _iter_slice(self, slice_: slice) -> Iterator[Record]:
        if slice_.step is not None:
            raise ValueError('Cannot iterate with a custom step')

        if (slice_.start is not None and slice_.stop is not None and
                slice_.start >= slice_.stop):
            raise ValueError('Cannot iterate backwards')

        if slice_.start is None:
            node = self._left_record_node
        else:
            node = self._search_in_tree(slice_.start, self._root_node)

        while True:
            for entry in node.entries:
                if slice_.start is not None and entry.key < slice_.start:
                    continue

                if slice_.stop is not None and entry.key >= slice_.stop:
                    return

                yield entry

            if node.next_page:
                node = self._mem.get_node(node.next_page)
            else:
                return

    def _search_in_tree(self, key, node) -> 'Node':
        if isinstance(node, (LonelyRootNode, LeafNode)):
            return node

        page = None

        if key < node.smallest_key:
            page = node.smallest_entry.before

        elif node.biggest_key <= key:
            page = node.biggest_entry.after

        else:
            for ref_a, ref_b in pairwise(node.entries):
                if ref_a.key <= key < ref_b.key:
                    page = ref_a.after
                    break

        assert page is not None

        child_node = self._mem.get_node(page)
        child_node.parent = node
        return self._search_in_tree(key, child_node)

    def _split_leaf(self, old_node: 'Node'):
        """Split a leaf Node to allow the tree to grow."""
        parent = old_node.parent
        new_node = self.LeafNode(page=self._mem.next_available_page,
                                 next_page=old_node.next_page)
        new_entries = old_node.split_entries()
        new_node.entries = new_entries
        ref = self.Reference(new_node.smallest_key,
                             old_node.page, new_node.page)

        if isinstance(old_node, LonelyRootNode):
            # Convert the LonelyRoot into a Leaf
            old_node = old_node.convert_to_leaf()
            self._create_new_root(ref)
        elif parent.can_add_entry:
            parent.insert_entry(ref)
            self._mem.set_node(parent)
        else:
            parent.insert_entry(ref)
            self._split_parent(parent)

        old_node.next_page = new_node.page

        self._mem.set_node(old_node)
        self._mem.set_node(new_node)

    def _split_parent(self, old_node: Node):
        parent = old_node.parent
        new_node = self.InternalNode(page=self._mem.next_available_page)
        new_entries = old_node.split_entries()
        new_node.entries = new_entries

        ref = new_node.pop_smallest()
        ref.before = old_node.page
        ref.after = new_node.page

        if isinstance(old_node, RootNode):
            # Convert the Root into an Internal
            old_node = old_node.convert_to_internal()
            self._create_new_root(ref)
        elif parent.can_add_entry:
            parent.insert_entry(ref)
            self._mem.set_node(parent)
        else:
            parent.insert_entry(ref)
            self._split_parent(parent)

        self._mem.set_node(old_node)
        self._mem.set_node(new_node)

    def _create_new_root(self, reference: Reference):
        new_root = self.RootNode(page=self._mem.next_available_page)
        new_root.insert_entry(reference)
        self._root_node_page = new_root.page
        self._mem.set_metadata(self._root_node_page, self._tree_conf)
        self._mem.set_node(new_root)

    @abstractmethod
    def _get_value_from_record(self, record: Record) -> bytes:
       pass


class SingleItemTree(BaseTree):
    """BPlusTree that uses a fixed value length.

    All use of overflow pages are abolished
    """
    __slots__ = []

    def _conf(
        self, page_size: int, key_size: int, value_size: int,
        serializer: Optional[Serializer] = None
    ) -> TreeConf:
        return TreeConf(
            page_size, page_size // (value_size+24), key_size, value_size, value_size,
            serializer or IntSerializer()
        )

    def insert(self, key, value: Union[bytes, set, list]):
        """Insert a value in the tree.

        :param key: The key at which the value will be recorded, must be of the
                    same type used by the Serializer
        :param value: The value to record in bytes
        :param replace: If True, already existing value will be overridden,
                        otherwise a ValueError is raised.
        """
        if not isinstance(value, bytes):
            raise TypeError("Value must be bytes.")
        if len(value) > self._tree_conf.value_size:
            raise ValueError("Value is larger than allowed size")

        with self._mem.write_transaction:
            node = self._search_in_tree(key, self._root_node)

            # Check if a record with the key already exists
            try:
                node.get_entry(key)
            except ValueError:
                record = self.Record(key, value=value)

                if node.can_add_entry:
                    node.insert_entry(record)
                    self._mem.set_node(node)
                else:
                    node.insert_entry(record)
                    self._split_leaf(node)
            else:
                raise ValueError("Key already exists")

    def update(self, key, value: Union[bytes, set, list]):
        """Update an existing record."""
        if not isinstance(value, bytes):
            raise TypeError("Value must be bytes.")
        if len(value) > self._tree_conf.value_size:
            raise ValueError("Value is larger than allowed size")

        with self._mem.write_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                raise ValueError("Record to update doesn't exist")
            else:
                record.value = value
                record.overflow_page = None
                self._mem.set_node(node)

    def batch_insert(self, iterable: Iterable):
        """Insert many elements in the tree at once.

        The iterable object must yield tuples (key, value) in ascending order.
        All keys to insert must be bigger than all keys currently in the tree.
        All inserts happen in a single transaction. This is way faster than
        manually inserting in a loop.
        """
        node = None
        with self._mem.write_transaction:

            for key, value in iterable:

                if node is None:
                    node = self._search_in_tree(key, self._root_node)

                try:
                    biggest_entry = node.biggest_entry
                except IndexError:
                    biggest_entry = None
                if biggest_entry and key <= biggest_entry.key:
                    raise ValueError('Keys to batch insert must be sorted and '
                                     'bigger than keys currently in the tree')

                if len(value) > self._tree_conf.value_size:
                    raise ValueError("Value is larger than allowed size")
                record = self.Record(key, value=value)

                if node.can_add_entry:
                    node.insert_entry_at_the_end(record)
                else:
                    node.insert_entry_at_the_end(record)
                    self._split_leaf(node)
                    node = None

            if node is not None:
                self._mem.set_node(node)

    def get(self, key, default=None) -> bytes:
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                return default
            else:
                rv = self._get_value_from_record(record)
                assert isinstance(rv, bytes)
                return rv

    def delete(self, key, default=None) -> bytes:
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                pass
            else:
                node.remove_entry(key)
                self._mem.set_node(node)

    def _get_value_from_record(self, record: Record) -> bytes:
        return record.value


class MultiItemIterator(collections.abc.Iterator):
    """Iterator that iterates over a multi item generator."""
    def __init__(self, generator: Generator, count: int):
        self.__count = count
        self.__generator = generator

    def __iter__(self):
        return self

    def __next__(self):
        return next(self.__generator)

    def __len__(self):
        return self.__count


class MultiItemTree(BaseTree):
    """BPlusTree that uses values with sets/lists of items.

    All items are stored in overflow pages.
    """
    __slots__ = []

    def _conf(
        self, page_size: int, key_size: int, value_size: int,
        serializer: Optional[Serializer] = None
    ) -> TreeConf:
        return TreeConf(
            page_size, page_size // (OTHERS_BYTES + 24), key_size, OTHERS_BYTES, value_size,
            serializer or IntSerializer()
        )

    def insert(self, key, value: Union[bytes, set, list]):
        """Insert a value in the tree.

        :param key: The key at which the value will be recorded, must be of the
                    same type used by the Serializer
        :param value: The value to record in bytes
        :param replace: If True, already existing value will be overridden,
                        otherwise a ValueError is raised.
        """
        if not isinstance(value, (set, list)):
            raise TypeError("Value must be set or list.")

        with self._mem.write_transaction:
            node = self._search_in_tree(key, self._root_node)

            # Check if a record with the key already exists
            try:
                node.get_entry(key)
            except ValueError:
                length = len(value)
                value = tuple(value)
                first_overflow_page = self._create_overflow(value)
                record = self.Record(
                    key,
                    value=length.to_bytes(OTHERS_BYTES, byteorder=ENDIAN),
                    overflow_page=first_overflow_page
                )

                if node.can_add_entry:
                    node.insert_entry(record)
                    self._mem.set_node(node)
                else:
                    node.insert_entry(record)
                    self._split_leaf(node)
            else:
                raise ValueError("Key already exists")

    def update(self, key, insertions: list = list(), deletions: set = set()):
        """Update an existing record."""
        if not insertions and not deletions:
            return

        with self._mem.write_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                raise ValueError("Record to update doesn't exist")
            else:
                record.overflow_page, record.value = self._update_overflow(
                    record.overflow_page,
                    int.from_bytes(record.value, ENDIAN),
                    insertions,
                    deletions
                )
                self._mem.set_node(node)

    def batch_insert(self, iterable: Iterable):
        raise NotImplementedError()

    def get(self, key, default=list()) -> list:
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                return default
            else:
                rv = self._get_value_from_record(record)
                assert isinstance(rv, list)
                return rv

    def delete(self, key, default=None) -> bytes:
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                pass
            else:
                node.remove_entry(key)
                self._mem.set_node(node)

    def _create_overflow(self, value: tuple) -> int:
        size = self._tree_conf.item_size
        count = len(value)
        serializer = self._tree_conf.serializer

        batch = self.OverflowNode().max_payload // size
        batch_cnt = count // batch
        batch_cnt += 1 if bool(count % batch) else 0

        first_overflow_page = self._mem.next_available_page
        next_overflow_page = first_overflow_page

        for batch_idx in range(batch_cnt):
            current_overflow_page = next_overflow_page

            chunk = value[batch_idx*batch:batch_idx*batch+batch]
            data_write = b""
            for item in chunk:
                if item is bytes:
                    data_write += item
                else:
                    data_write += serializer.serialize(item, size)

            if batch_idx == batch_cnt-1:
                next_overflow_page = None
            else:
                next_overflow_page = self._mem.next_available_page

            overflow_node = self.OverflowNode(
                page=current_overflow_page, next_page=next_overflow_page
            )
            overflow_node.insert_entry_at_the_end(OpaqueData(data=data_write))
            self._mem.set_node(overflow_node)

        return first_overflow_page

    def _traverse_overflow(self, first_overflow_page: int):
        """Yield all Nodes of an overflow chain."""
        next_overflow_page = first_overflow_page
        while True:
            overflow_node = self._mem.get_node(next_overflow_page)
            yield overflow_node

            next_overflow_page = overflow_node.next_page
            if next_overflow_page is None:
                break

    def _read_from_overflow(self, first_overflow_page: int, count: int) -> list:
        """Collect all values of an overflow chain."""
        size = self._tree_conf.item_size
        serializer = self._tree_conf.serializer

        batch = self.OverflowNode().max_payload // size
        batch_cnt = count // batch
        batch_cnt += 1 if bool(count % batch) else 0

        rv = list()
        rest = count
        for overflow_node in self._traverse_overflow(first_overflow_page):
            chunk = overflow_node.smallest_entry.data[0:batch*size]
            for item_idx in range(min(batch, rest)):
                item = chunk[item_idx*size:item_idx*size+size]
                rv.append(item)
            rest -= batch

        if len(rv) != count:
            raise ValueError("The list length didn't match the count")

        return rv

    def _iterate_from_overflow(self, first_overflow_page: int, count: int, insertions: list = list()):
        """Collect all values of an overflow chain."""
        size = self._tree_conf.item_size
        serializer = self._tree_conf.serializer

        for item in insertions:
            if type(item) is bytes:
                yield item
            else:
                yield serializer.serialize(item, size)

        for overflow_node in self._traverse_overflow(first_overflow_page):
            data = overflow_node.smallest_entry.data
            length = len(data)
            for item_offset in range(0, length, size):
                yield data[item_offset:item_offset+size]
                count -= 1
            self._mem.del_node(overflow_node)

        if count != 0:
            raise ValueError("Failed reading all values, %s values left" % count)

    def _add_overflow(self, next_overflow_page: int, chunk: list, is_last: bool = False) -> int:
        size = self._tree_conf.item_size
        serializer = self._tree_conf.serializer

        current_overflow_page = next_overflow_page

        data = b""
        for item in chunk:
            if type(item) is bytes:
                data += item
            else:
                data += serializer.serialize(item, size)

        if is_last:
            next_overflow_page = None
        else:
            next_overflow_page = self._mem.next_available_page

        overflow_node = self.OverflowNode(
            page=current_overflow_page, next_page=next_overflow_page
        )
        overflow_node.insert_entry_at_the_end(OpaqueData(data=data))
        self._mem.set_node(overflow_node)

        return next_overflow_page

    def _update_overflow(
            self, first_overflow_page: int, count: int,
            insertions: list = list(), deletions: set = set()
    ):
        """Insert and delete items to/from value.

        The old overflow pages are filtered and discarded. A new overflow is created.

        Args:
            first_overflow_page (int):
                The old overflow
            count (int):
                Number of items
            insertions (list):
                Items to be inserted
            deletions (set):
                Items to be deleted, filtered

        Returns (int, int):
            New overflow and count

        """
        size = self._tree_conf.item_size
        serializer = self._tree_conf.serializer

        batch = self.OverflowNode().max_payload // size
        batch_cnt = count // batch
        batch_cnt += 1 if bool(count % batch) else 0

        new_first_overflow_page = self._mem.next_available_page
        next_overflow_page = new_first_overflow_page

        chunk = list()
        length = 0
        new_count = 0
        for item in self._iterate_from_overflow(first_overflow_page, count, insertions):
            if item not in deletions:
                chunk.append(item)
                length += 1
                new_count += 1

            if length == batch:
                next_overflow_page = self._add_overflow(next_overflow_page, chunk)
                chunk = list()
                length = 0

        if length > 0:
            self._add_overflow(next_overflow_page, chunk, True)

        return new_first_overflow_page, new_count

    def _delete_overflow(self, first_overflow_page: int):
        """Delete all Nodes in an overflow chain."""
        for overflow_node in self._traverse_overflow(first_overflow_page):
            self._mem.del_node(overflow_node)

    def _get_value_from_record(self, record: Record) -> list:
        return self._read_from_overflow(record.overflow_page, int.from_bytes(record.value, ENDIAN))

    def traverse(self, key) -> MultiItemIterator:
        """Like get but returns an iterator."""
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                return None
            else:
                count = int.from_bytes(record.value, ENDIAN)
                generator = (functools.partial(self._iterate_overflow, record.overflow_page, count)())
                return MultiItemIterator(generator, count)

    def _iterate_overflow(self, first_overflow_page: int, count: int):
        """Collect all values of an overflow chain."""
        """size = self._tree_conf.item_size
        serializer = self._tree_conf.serializer

        batch = self.OverflowNode().max_payload // size
        batch_cnt = count // batch
        batch_cnt += 1 if bool(count % batch) else 0

        rv = list()
        rest = count
        for overflow_node in self._traverse_overflow(first_overflow_page):
            chunk = overflow_node.smallest_entry.data[0:batch*size]
            for item_idx in range(min(batch, rest)):
                yield chunk[item_idx*size:item_idx*size+size]
            rest -= batch

        if rest != 0:
            raise ValueError("Failed reading all values")"""
        size = self._tree_conf.item_size
        serializer = self._tree_conf.serializer

        for overflow_node in self._traverse_overflow(first_overflow_page):
            data = overflow_node.smallest_entry.data
            length = len(data)
            for item_offset in range(0, length, size):
                yield serializer.deserialize(data[item_offset:item_offset+size])
                count -= 1

        if count != 0:
            raise ValueError("Failed reading all values, %s values left" % count)