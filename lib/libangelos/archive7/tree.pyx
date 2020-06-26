# cython: language_level=3
#
# Copyright (c) 2020 by Kristoffer Paulsson
# This file is distributed under the terms of the MIT license.
#

import bisect
import collections
import datetime
import functools
import io
import itertools
import math
import struct
import time
import uuid
from abc import ABC, abstractmethod
from collections import namedtuple
from collections.abc import Mapping
from contextlib import ContextDecorator, AbstractContextManager
from contextvars import ContextVar
from typing import Union, Iterator, Iterable, Generator, Type

from libangelos.utils import Util


class EntryNotFound(RuntimeWarning):
    """Entry not found in node based on key."""
    pass


class DataLoaderDumper(ABC):
    """Data load/dump data base class."""

    @abstractmethod
    def load(self, data: bytes):
        """Abstract data load and deserialization method."""
        pass

    @abstractmethod
    def dump(self) -> bytes:
        """Abstract data serialization and dump method."""
        pass


Configuration = namedtuple(
    "Configuration", "order ref_order item_order value_size item_size page_size meta node reference record blob comparator")


class Comparable:
    """Compare keys."""

    __slots__ = []

    def __eq__(self, other):
        return self.key == other.key

    def __lt__(self, other):
        return self.key < other.key

    def __le__(self, other):
        return self.key <= other.key

    def __gt__(self, other):
        return self.key > other.key

    def __ge__(self, other):
        return self.key >= other.key


class Entry(DataLoaderDumper):
    """Entry base class."""

    __slots__ = ["_conf"]

    def __init__(self, conf: Configuration, data: bytes = None):
        self._conf = conf
        # self._data = data

        if data:
            self.load(data)


class Record(Entry, Comparable):
    """Record entry using key/value-pair."""

    __slots__ = ["key", "value", "page"]

    def __init__(
            self, conf: Configuration, data: bytes = None, key: uuid.UUID = None,
            value: Union[bytes, int] = None, page: int = -1
    ):
        if value is type(tuple):
            raise TypeError("Value cant be tuple")

        Entry.__init__(self, conf, data)

        if not data:
            self.key = key
            self.value = value
            self.page = page

        if self.page is None:
            raise RuntimeError("Page index not set")

    def load(self, data: bytes):
        """Unpack data consisting of page number, key and value."""
        self.page, key, self.value, cs = self._conf.record.unpack(data)
        value = self.value.to_bytes(4, "big") if isinstance(self.value, int) else self.value
        if bytes([sum(key+value) & 0xFF]) != cs:
            raise RuntimeError("Record checksum mismatch")
        self.key = uuid.UUID(bytes=key)

    def dump(self) -> bytes:
        """Packing data consisting of page number, key and value."""
        value = self.value.to_bytes(4, "big") if isinstance(self.value, int) else self.value
        return self._conf.record.pack(
            self.page, self.key.bytes, self.value,
            bytes([sum(self.key.bytes+value) & 0xFF])
        )


class Reference(Entry, Comparable):
    """Reference entry for internal structure."""

    __slots__ = ["key", "before", "after"]

    def __init__(self, conf: Configuration, data: bytes = None, key: uuid.UUID = None, before: int = -1,
                 after: int = -1):
        Entry.__init__(self, conf, data)

        if not data:
            self.key = key
            self.before = before
            self.after = after

    def load(self, data: bytes):
        """Unpack data consisting of before, after and key."""
        self.before, self.after, key = self._conf.reference.unpack(data)
        self.key = uuid.UUID(bytes=key)

    def dump(self) -> bytes:
        """Packing data consisting of before, after and key."""
        return self._conf.reference.pack(self.before, self.after, self.key.bytes)


class Blob(Entry):
    """Blob entry for opaque data."""

    __slots__ = ["data"]

    def __init__(self, conf: Configuration, data: bytes, items: list = list()):
        self.items = items
        Entry.__init__(self, conf, data)

    def load(self, data: bytes):
        """Load data into storage."""
        count = self._conf.blob.unpack_from(data[:self._conf.blob.size])[0]

        if count > self._conf.item_order:
            raise RuntimeError("Item count higher than specified order.")

        size = self._conf.item_size
        for offset in range(self._conf.blob.size, size * count, size):
            self.items.append(data[offset:offset+size])

    def dump(self) -> bytes:
        """Dump data from storage."""
        if len(self.items) > self._conf.item_order:
            raise RuntimeError("Item count higher than specified order.")

        data = self._conf.blob.pack(len(self.items))
        for item in self.items:
            data += item

        return data


class Comparator(Comparable):
    """Comparable dummy."""

    __slots__ = ["key"]

    def __init__(self):
        self.key = None


class Node:
    """Node base class"""

    __slots__ = ["_conf", "data", "page", "next"]

    NODE_KIND = b""
    ENTRY_CLASS = None

    def __init__(self, conf: Configuration, data: bytes, page: int, next_: int = -1):
        self._conf = conf
        self.page = page  # Current page index
        self.next = next_  # Next node page index

        if data:
            self.load(data)

    def __bytes__(self) -> bytes:
        return self.dump()

    def __repr__(self):
        return "<{}: page={} next={}>".format(self.__class__.__name__, self.page, self.next)


class StackNode(Node):
    """Node class for nodes that are part of a stack."""

    __slots__ = []

    MAX_ENTRIES = 0

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1):
        Node.__init__(self, conf, data, page, next_)


class DataNode(StackNode, DataLoaderDumper):
    """Node class for arbitrary data."""

    __slots__ = ["blob"]

    NODE_KIND = b"D"
    ENTRY_CLASS = Blob
    MAX_ENTRIES = 1

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1):
        StackNode.__init__(self, conf, data, page, next_)
        self.blob = None

    def load(self, data: bytes):
        """Unpack data consisting of node meta and entries."""
        if len(data) != self._conf.page_size:
            raise ValueError("Page data is not of set page size")

        kind, self.next, count = self._conf.node.unpack(data[:self._conf.node.size])

        if kind != self.NODE_KIND:
            raise TypeError("Can not load data for wrong node type")
        if count > self.MAX_ENTRIES:
            raise ValueError("Page has a higher count than the allowed order")

        size = self._conf.blob.unpack_from(data[self._conf.node.size:])[0]

        if (self._conf.node.size + self._conf.blob.size + size) > self._conf.page_size:
            raise ValueError("Blob size larger than fits in page data")

        self.blob = self.ENTRY_CLASS(self._conf, data[self._conf.node.size: self._conf.blob.size + size])

    def dump(self) -> bytes:
        """Packing data consisting of node meta and entries."""
        data = self._conf.node.pack(self.NODE_KIND, self.next, 1 if self.blob else 0)
        data += self.blob.dump()

        if not len(data) < self._conf.page_size:
            raise ValueError("Data larger than page size")
        else:
            data += bytes(self._conf.page_size - len(data))

        return data


class ItemsNode(StackNode, DataLoaderDumper):
    """Node class for recycled nodes."""

    __slots__ = []

    NODE_KIND = b"I"

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1):
        self.items = list()
        StackNode.__init__(self, conf, data, page, next_)

    def load(self, data: bytes):
        """Unpack data consisting of node meta and entries."""

        if len(data) != self._conf.page_size:
            raise ValueError("Page data is not of set page size")

        kind, self.next, count = self._conf.node.unpack(data[:self._conf.node.size])

        if kind != self.NODE_KIND:
            raise TypeError("Can not load data for wrong node type")
        if count > self._conf.item_order:
            raise RuntimeError("Item count higher than specified order.")

        size = self._conf.item_size
        for offset in range(self._conf.node.size, count * size + self._conf.node.size, size):
            self.items.append(data[offset:offset+size])

    def dump(self) -> bytes:
        """Packing data consisting of node meta and entries."""
        if len(self.items) > self._conf.item_order:
            raise RuntimeError("Item count higher than specified order.")

        data = self._conf.node.pack(self.NODE_KIND, self.next, len(self.items))

        for item in self.items:
            if len(item) != self._conf.item_size:
                raise RuntimeError("Item not of item size %s" % self._conf.item_size)

            data += item

        data += bytes(self._conf.page_size - len(data))
        return data


class EmptyNode(StackNode, DataLoaderDumper):
    """Node class for recycled nodes."""

    __slots__ = []

    NODE_KIND = b"E"

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1):
        StackNode.__init__(self, conf, data, page, next_)

    def load(self, data: bytes):
        """Unpack data consisting of node meta and entries."""
        if len(data) != self._conf.page_size:
            raise ValueError("Page data is not of set page size")

        kind, self.next, _ = self._conf.node.unpack(data[:self._conf.node.size])

        if kind != self.NODE_KIND:
            raise TypeError("Can not load data for wrong node type")

    def dump(self) -> bytes:
        """Packing data consisting of node meta and entries."""
        data = self._conf.node.pack(self.NODE_KIND, self.next, 0)
        data += bytes(self._conf.page_size - len(data))

        return data


class HierarchyNode(Node, DataLoaderDumper):
    """Node class for managing the btree hierarchy."""

    __slots__ = ["parent", "entries", "max", "min"]

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1, parent: Node = None):
        self.parent = parent
        self.entries = list()
        Node.__init__(self, conf, data, page)

    def is_not_full(self) -> bool:
        """Can entries be added."""
        return self.length() < self.max

    def is_not_empty(self) -> bool:
        """Can entries be deleted."""
        return self.length() > self.min

    def least_entry(self) -> Entry:
        """Get least entry"""
        return self.entries[0]

    def least_key(self) -> uuid.UUID:
        """Get least key"""
        return self.least_entry().key

    def largest_entry(self) -> Entry:
        """Get largest entry"""
        return self.entries[-1]

    def largest_key(self) -> uuid.UUID:
        """Get largest key"""
        return self.largest_entry().key

    def length(self) -> int:
        """Number of entries"""
        return len(self.entries)

    def pop_least(self) -> Entry:
        """Remove and return the least entry."""
        return self.entries.pop(0)

    def insert_entry(self, entry: Entry):
        """Insert an entry."""
        bisect.insort(self.entries, entry)

    def delete_entry(self, key: uuid.UUID):
        """Delete entry by key,"""
        self.entries.pop(self._find_by_key(key))

    def get_entry(self, key: uuid.UUID) -> Entry:
        """Get entry by key."""
        return self.entries[self._find_by_key(key)]

    def _find_by_key(self, key: uuid.UUID) -> int:
        comparator = self._conf.comparator
        comparator.key = key
        i = bisect.bisect_left(self.entries, comparator)

        if i >= len(self.entries) or self.entries[i] != comparator:
            raise EntryNotFound('No entry for key {}'.format(key))

        return i

    def split_entries(self) -> list:
        """Split an entry in two halves and return half of all entries."""
        length = len(self.entries)
        if length > 4:
            RuntimeError("At least 4 entries in order to split a node")
        rest = self.entries[length // 2:]
        self.entries = self.entries[:length // 2]
        if len(rest) + len(self.entries) != length:
            raise RuntimeError("The total number of entries is different")
        return rest

    def load(self, data: bytes):
        """Unpack data consisting of node meta and entries."""
        if len(data) != self._conf.page_size:
            raise ValueError("Page data is not of set page size")

        kind, self.next, count = self._conf.node.unpack(data[:self._conf.node.size])

        if kind != self.NODE_KIND:
            raise TypeError("Can not load data for wrong node type")

        # if count > self._conf.order:
        #     raise ValueError("Page has a higher count than the current order")

        if count > self.max:
            raise ValueError("Page has a higher count than the current order %s" % self.max)

        size = self._conf.record.size if self.NODE_KIND in (b"L", b"S") else self._conf.reference.size

        if size * count + self._conf.node.size > self._conf.page_size:
            raise ValueError("Entry count higher than fits in page data")

        for offset in range(self._conf.node.size, count * size + self._conf.node.size, size):
            self.entries.append(self.ENTRY_CLASS(self._conf, data=data[offset:offset + size]))

    def dump(self) -> bytes:
        """Packing data consisting of node meta and entries."""
        data = self._conf.node.pack(self.NODE_KIND, self.next, len(self.entries))

        for entry in self.entries:
            data += entry.dump()

        if len(data) > self._conf.page_size:
            raise ValueError("Data larger than page size")
        else:
            data += bytes(self._conf.page_size - len(data))

        return data

    def __repr__(self):
        return "<{}: page={} next={} parent={} min={} max={} count={}>".format(
            self.__class__.__name__, self.page, self.next, self.parent,
            self.min, self.max, len(self.entries)
        )


class RecordNode(HierarchyNode):
    """Node class that is used as leaf node of records."""

    __slots__ = []

    ENTRY_CLASS = Record

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1, parent: Node = None):
        self.max = conf.order
        HierarchyNode.__init__(self, conf, data, page, next_, parent)


class LeafNode(RecordNode):
    """Node class that is used as leaf node of records."""

    __slots__ = []

    NODE_KIND = b"L"

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1, parent: Node = None):
        self.min = math.ceil(conf.order / 2) - 1
        RecordNode.__init__(self, conf, data, page, next_, parent)


class StartNode(RecordNode):
    """When there only is one node this is the root."""

    __slots__ = []

    NODE_KIND = b"S"

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):
        self.min = 0
        RecordNode.__init__(self, conf, data, page, parent=parent)

    def convert(self):
        """Convert start node to normal node."""
        node = LeafNode(self._conf, page=self.page)
        node.entries = self.entries
        return node


class ReferenceNode(HierarchyNode):
    """Node class for holding references higher up than leaf nodes."""

    __slots__ = []

    ENTRY_CLASS = Reference

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):
        self.max = conf.ref_order
        HierarchyNode.__init__(self, conf, data, page, parent=parent)


class StructureNode(ReferenceNode):
    """Node class for references that isn't root node."""

    __slots__ = []

    NODE_KIND = b"F"

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):
        self.min = math.ceil(conf.ref_order / 2)
        ReferenceNode.__init__(self, conf, data, page, parent)

    def length(self) -> int:
        """Entries count."""
        return len(self.entries) + 1 if self.entries else 0

    def insert_entry(self, entry: Reference):
        """Make sure that after of a reference matches before of the next one.

        Probably very inefficient approach.
        """
        HierarchyNode.insert_entry(self, entry)
        i = self.entries.index(entry)
        pidx = i-1
        nidx = i+1

        if pidx >= 0:
            self.entries[pidx].after = entry.before

        if nidx < len(self.entries):
            self.entries[nidx].before = entry.after


class RootNode(ReferenceNode):
    """When there is several nodes this is the root."""

    __slots__ = []

    NODE_KIND = b"R"

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):
        self.min = 2
        ReferenceNode.__init__(self, conf, data, page, parent)

    def convert(self):
        """Convert root node to structure node."""
        node = StructureNode(self._conf, page=self.page)
        node.entries = self.entries
        return node


class Pager(Mapping):
    """Pager that wraps pages written to a file object, indexed like a list."""

    def __init__(self, fileobj: io.FileIO, size: int, meta: int = 0):
        self._fd = fileobj
        self.__size = size
        self.__meta = meta
        self.__pages = 0

        length = max(self._fd.seek(0, io.SEEK_END) - self.__meta, 0)
        if length:
            if length % self.__size:
                raise OSError("File of uneven length compared to page size of %s bytes" % self.__size)
            self.__pages = length // self.__size
        else:
            self.meta(bytes(meta))

    def close(self):
        """Close file descriptor."""
        self._fd.close()

    def meta(self, data: bytes = None) -> bytes:
        """Read or write meta-data chunk."""
        if data:
            if len(data) != self.__meta:
                raise ValueError("Data is not of meta size %s" % self.__meta)

            self._fd.seek(0)
            self._fd.write(data)
            return data
        else:
            self._fd.seek(0)
            return self._fd.read(self.__meta)

    # @lru_cache(maxsize=64, typed=True)
    def __getitem__(self, k: int) -> bytes:
        if not k < self.__pages:
            raise KeyError("Invalid key")

        offset = k * self.__size + self.__meta
        pos = self._fd.seek(offset)

        if pos != offset:
            raise OSError("Failed to seek to offset")

        return self._fd.read(self.__size)

    def __len__(self) -> int:
        return self.__pages

    def __iter__(self) -> bytes:
        for k in range(self.__pages):
            yield self[k]

    def write(self, data: Union[bytes, bytearray], index: int):
        """Write a page of data to an existing index."""
        if not index < self.__pages:
            raise IndexError("Out of bounds")
        if len(data) != self.__size:
            raise ValueError("Data size different from page size.")

        offset = index * self.__size + self.__meta
        pos = self._fd.seek(offset)

        if pos != offset:
            raise OSError("Failed to seek to offset")

        self._fd.write(data)

    # @lru_cache(maxsize=64, typed=True)
    def read(self, index: int):
        """Read a page of data from an existing index."""
        if not index < self.__pages:
            raise IndexError("Out of bounds")

        offset = index * self.__size + self.__meta
        pos = self._fd.seek(offset)

        if pos != offset:
            raise OSError("Failed to seek to offset")

        return self._fd.read(self.__size)

    def append(self, data: Union[bytes, bytearray]) -> int:
        """Append a page of data to the end of the list."""
        if len(data) != self.__size:
            raise ValueError("Data size different from page size.")

        self._fd.seek(0, io.SEEK_END)
        length = self._fd.write(data)

        if length != len(data):
            raise OSError("Didn't write all data")

        self.__pages += 1
        return self.__pages - 1


transaction_ctx = ContextVar("transact", default=None)


class Transact(ContextDecorator, AbstractContextManager):
    """BTree transaction context."""

    def __init__(self):
        self.__token = transaction_ctx.set(True)

    def __enter__(self):
        return transaction_ctx.get()

    def __evaluate(self):
        transaction = transaction_ctx.get()
        transaction_ctx.reset(self.__token)
        if not transaction:
            raise ValueError("No transaction context")

    def __exit__(self, exc_type, exc_value, traceback):
        if exc_type is not None:
            raise exc_type(exc_value)

        self.__evaluate()
        return None


class Tree(ABC):
    """Base tree class."""

    FORMAT_META = struct.Struct("!ciiIII")  # Meta, kind, root, empty, order, ref_order, value_size
    FORMAT_NODE = struct.Struct("!siI")  # Node: type, next, count
    FORMAT_REFERENCE = struct.Struct("!ii16s")  # Reference, before, after, key
    FORMAT_BLOB = struct.Struct("!I")

    TREE_KIND = None

    NODE_KINDS = {
        DataNode.NODE_KIND: DataNode,
        ItemsNode.NODE_KIND: ItemsNode,
        EmptyNode.NODE_KIND: EmptyNode,
        LeafNode.NODE_KIND: LeafNode,
        StartNode.NODE_KIND: StartNode,
        StructureNode.NODE_KIND: StructureNode,
        RootNode.NODE_KIND: RootNode
    }

    def __init__(self, fileobj: io.FileIO, conf: Configuration):
        self.__root = -1  # Page number for tree root node
        self.__empty = -1  # Page number of recycled page stack start

        self._conf = conf
        self._pager = Pager(fileobj, self._conf.page_size, self._conf.meta.size)

        if len(self._pager):
            k, o, ro, vs = self._meta_load()
            if self.TREE_KIND != k or o != conf.order or ro != conf.ref_order or vs != conf.value_size:
                raise RuntimeError("Class configuration doesn't match saved tree.")
        else:
            self._initialize()

    @classmethod
    @abstractmethod
    def config(cls, order: int, value_size: int) -> Configuration:
        """Generate configuration class."""
        pass

    def close(self):
        """Close memory."""
        self._pager.close()

    def _get_node(self, page: int) -> Node:
        """Loads node from page and deserializes it."""

        data = self._pager.read(page)
        kind = bytes([data[0]])

        if kind not in self.NODE_KINDS.keys():
            raise TypeError("Unknown node type: %s" % kind)

        return self.NODE_KINDS[kind](self._conf, data=data, page=page)

    def _set_node(self, node: Node):
        """Save node to page on file."""
        self._pager.write(node.dump(), node.page)

    def _del_node(self, node: Node):
        """Delete by node instance, node page is recycled."""
        self._recycle(node.page)

    def _del_page(self, page: int):
        """Delete page by page index, node page is recycled."""
        self._recycle(page)

    def _traverser(self, page: int):
        """Iterator that traverses over a node chain."""
        while page != -1:
            node = self._get_node(page)
            page = node.next
            yield node

    def _meta_load(self) -> tuple:
        """Load meta-data."""
        (
            kind, self.__root, self.__empty, order, ref_order, value_size
        ) = self._conf.meta.unpack(self._pager.meta())
        return kind, order, ref_order, value_size

    def _meta_save(self):
        """Save meta-data."""
        self._pager.meta(self._conf.meta.pack(
            self.TREE_KIND, self.__root, self.__empty,
            self._conf.order, self._conf.ref_order, self._conf.value_size
        ))

    def _new_page(self) -> int:
        page = self._unshift_empty()

        if not page:
            page = self._pager.append(bytes(self._conf.page_size))

        return page

    def _shift_empty(self, page: int):
        self._set_node(EmptyNode(self._conf, page=page, next_=self.__empty))
        self.__empty = page
        self._meta_save()

    def _unshift_empty(self) -> int:
        if self.__empty == -1:
            return None
        else:
            node = self._get_node(self.__empty)
            self.__empty = node.next
            self._meta_save()
            return node.page

    def _recycle(self, page: int):
        self._shift_empty(page)

    def do_wal(self):
        """Read and execute journal"""
        pass

    def checkpoint(self):
        """Write commit transaction into the tree."""
        # with self._mem.write_transaction:
        self.do_wal()

        # TODO: Fix this function

    def _initialize(self):
        """Initialize a tree for the first time."""
        self.__root = self._new_page()
        # with self._mem.write_transaction:
        self._set_node(StartNode(self._conf, page=self.__root))
        self._meta_save()

    def _root_node(self) -> Union[StartNode, RootNode]:
        """Load the root node."""
        node = self._get_node(self.__root)
        if not isinstance(node, (StartNode, RootNode)):
            RuntimeError("Root node not of type StartNode/RootNode instead type %s" % type(node))

        return node

    def _left_record_node(self) -> RecordNode:
        node = self._root_node()
        while not isinstance(node, RecordNode):
            node = self._get_node(node.least_entry().before)
        return node

    def _pairs(self, iterable: Iterable):
        a, b = itertools.tee(iterable)
        next(b, None)
        return zip(a, b)

    def _search(self, key: uuid.UUID, node: HierarchyNode) -> HierarchyNode:
        if isinstance(node, RecordNode):  # RecordNode has LeafNode and StartNode as subclasses
            return node

        page = None

        if key < node.least_key():
            page = node.least_entry().before
        elif node.largest_key() <= key:
            page = node.largest_entry().after
        else:
            for ref_a, ref_b in self._pairs(node.entries):
                if ref_a.key <= key < ref_b.key:
                    page = ref_a.after
                    break

        if page is not None:
            RuntimeError("Page search error")

        child = self._get_node(page)
        child.parent = node
        return self._search(key, child)

    def _iterate(self, part: slice) -> Iterator[Record]:
        if part.step is not None:
            raise ValueError('Cannot iterate with a custom step')

        if (part.start is not None and part.stop is not None and
                part.start >= part.stop):
            raise ValueError('Cannot iterate backwards')

        if part.start is None:
            node = self._left_record_node()
        else:
            node = self._search(part.start, self._root_node())

        while True:
            for entry in node.entries:
                if part.start is not None and entry.key < part.start:
                    continue

                if part.stop is not None and entry.key >= part.stop:
                    return

                yield entry

            if node.next:
                node = self._get_node(node.next)
            else:
                return

    def _construct_root(self, reference: Reference):
        node = RootNode(self._conf, page=self._new_page())
        node.insert_entry(reference)
        self.__root = node.page
        self._meta_save()
        self._set_node(node)

    def _cleave_node(self, node: RecordNode):  # node: HierarchyNode):
        parent = node.parent
        sliver = LeafNode(self._conf, page=self._new_page(), next_=node.next)
        sliver.entries = node.split_entries()
        reference = Reference(self._conf, key=sliver.least_key(), before=node.page, after=sliver.page)

        if isinstance(node, StartNode):
            node = node.convert()
            self._construct_root(reference)
        elif parent.is_not_full():
            parent.insert_entry(reference)
            self._set_node(parent)
        else:
            parent.insert_entry(reference)
            self._cleave_parent(parent)

        node.next = sliver.page

        if not len(node.entries) > 0 and len(sliver.entries) > 0:
            raise RuntimeError("Failed splitting node, to few entries")

        self._set_node(node)
        self._set_node(sliver)

    def _cleave_parent(self, node: ReferenceNode):  # node: Node):
        parent = node.parent
        sliver = StructureNode(self._conf, page=self._new_page())
        sliver.entries = node.split_entries()

        reference = sliver.pop_least()
        reference.before = node.page
        reference.after = sliver.page

        if isinstance(node, RootNode):
            node = node.convert()
            self._construct_root(reference)
        elif parent.is_not_full():
            parent.insert_entry(reference)
            self._set_node(parent)
        else:
            parent.insert_entry(reference)
            self._cleave_parent(parent)

        if not len(node.entries) > 0 and len(sliver.entries) > 0:
            raise RuntimeError("Failed splitting node, to few entries")

        self._set_node(node)
        self._set_node(sliver)

    @abstractmethod
    def insert(self, key: uuid.UUID, value: Union[bytes, memoryview, set, list]):
        """Insert key and value into the tree.

        :param key:
        :param value:
        :return:
        """
        pass

    @abstractmethod
    def update(self, key: uuid.UUID, value: Union[bytes, memoryview, set, list]):
        """Update key with value in the tree.

        :param key:
        :param value:
        :return:
        """
        pass

    @abstractmethod
    def get(self, key: uuid.UUID) -> bytes:
        """Get value from the tree using key.

        :param key:
        :return:
        """
        pass

    @abstractmethod
    def delete(self, key: uuid.UUID) -> bytes:
        """Delete entry from the tree using key.

        :param key:
        :return:
        """
        pass

    @abstractmethod
    def _get_value_from_record(self, record: Record) -> bytes:
        pass

    @classmethod
    def factory(cls, fileobj: io.FileIO, order: int, value_size: int, page_size: int = None) -> "Tree":
        """Create a new BTree instance."""
        return cls(fileobj, cls.config(order, value_size, page_size))


class SimpleBTree(Tree):
    """BTree that handles single item values."""

    TREE_KIND = b"S"

    @classmethod
    def config(cls, order: int, value_size: int, page_size: int = None) -> Configuration:
        """Generate configuration class."""

        if order < 4:
            raise OSError("Order can never be less than 4.")

        record = struct.Struct("!i16s{}sc".format(value_size))  # Record: page, key, value, checksum
        ref_order = math.ceil(order * record.size / cls.FORMAT_REFERENCE.size)
        ps = cls.FORMAT_NODE.size + ref_order * cls.FORMAT_REFERENCE.size

        if page_size:
            if ps > page_size:
                raise RuntimeError("Page size is to small, %s is needed" % ps)
        else:
            page_size = ps

        return Configuration(
            order, ref_order, 0, value_size, 0, page_size, cls.FORMAT_META,
            cls.FORMAT_NODE, cls.FORMAT_REFERENCE, record, cls.FORMAT_BLOB, Comparator()
        )

    def insert(self, key: uuid.UUID, value: bytes):
        """Insert key and value into the tree.

        :param key:
        :param value:
        :return:
        """
        if len(value) > self._conf.value_size:
            raise ValueError("Value is larger than allowed size")

        # with self._mem.write_transaction:
        node = self._search(key, self._root_node())

        try:
            node.get_entry(key)
        except EntryNotFound:
            record = Record(self._conf, key=key, value=value)

            if node.is_not_full():
                node.insert_entry(record)
                self._set_node(node)
            else:
                node.insert_entry(record)
                self._cleave_node(node)
        else:
            raise ValueError("Key already exists")

    def update(self, key: uuid.UUID, value: bytes):
        """Update key with value in the tree.

        :param key:
        :param value:
        :return:
        """

        if len(value) > self._conf.value_size:
            raise ValueError("Value is larger than allowed size")

        # with self._mem.write_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except EntryNotFound:
            raise ValueError("Key doesn't exist")
        else:
            record.value = value
            self._set_node(node)

    def get(self, key: uuid.UUID) -> bytes:
        """Get value from the tree using key.

        :param key:
        :return:
        """
        # with self._mem.read_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except EntryNotFound:
            return None
        else:
            return self._get_value_from_record(record)

    def delete(self, key: uuid.UUID):
        """Delete entry from the tree using key.

        :param key:
        :return:
        """
        # with self._mem.read_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except EntryNotFound:
            pass
        else:
            node.delete_entry(key)
            self._set_node(node)

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


class MultiBTree(Tree):
    """BTree that handles multi-item values."""

    TREE_KIND = b"M"

    @classmethod
    def config(cls, order: int, value_size: int, page_size: int = None) -> Configuration:
        """Generate configuration class."""

        if order < 4:
            raise OSError("Order can never be less than 4.")

        ps = cls.FORMAT_NODE.size + order * value_size
        record = struct.Struct("!i16sIc")  # Record: page, key, value, checksum
        rec_order = (ps - cls.FORMAT_NODE.size) // record.size
        ref_order = (ps - cls.FORMAT_NODE.size) // cls.FORMAT_REFERENCE.size

        if page_size:
            if ps > page_size:
                raise RuntimeError("Page size is to small, %s is needed" % ps)
        else:
            page_size = ps

        return Configuration(
            rec_order, ref_order, order, 4, value_size, page_size, cls.FORMAT_META,
            cls.FORMAT_NODE, cls.FORMAT_REFERENCE, record, cls.FORMAT_BLOB, Comparator()
        )

    def insert(self, key: uuid.UUID, value: Union[set, list]):
        """Insert key and values into the tree.

        :param key:
        :param value:
        :return:
        """
        node = self._search(key, self._root_node())

        try:
            node.get_entry(key)
        except EntryNotFound:
            length = len(value)
            value = tuple(value)
            page = self._create_overflow(value) if value else -1

            record = Record(
                self._conf,
                key=key,
                value=length,
                page=page
            )

            if node.is_not_full():
                node.insert_entry(record)
                self._set_node(node)
            else:
                node.insert_entry(record)
                self._cleave_node(node)
        else:
            raise ValueError("Key already exists")

    def update(self, key: uuid.UUID, insertions: list = list(), deletions: set = set()):
        """Update key with values to be inserted and deleted in the tree.

        :param key:
        :param insertions:
        :param deletions:
        :return:
        """
        if not insertions and not deletions:
            return

        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except EntryNotFound:
            raise ValueError("Record to update doesn't exist")
        else:
            if record.value > 0:
                record.page, record.value = self._update_items(
                    record.page,
                    record.value,
                    insertions,
                    deletions
                )
            else:
                record.value = len(insertions)
                record.page = self._create_overflow(tuple(insertions))

            self._set_node(node)

    def get(self, key: uuid.UUID) -> list:
        """Get values from the tree using key.

        :param key:
        :return:
        """
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except EntryNotFound:
            return list()
        else:
            if record.value > 0:
                return self._get_value_from_record(record)
            else:
                return list()

    def delete(self, key: uuid.UUID):
        """Delete entry from the tree using key.

        :param key:
        :return:
        """
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except EntryNotFound:
            pass
        else:
            if record.value > 0:
                self._delete_node_chain(record.page)
            node.delete_entry(key)
            self._set_node(node)

    def clear(self, key: uuid.UUID):
        """Clear all values from entry in the tree.

        :param key:
        :return:
        """
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except EntryNotFound:
            pass
        else:
            length = record.value
            if length:
                self._delete_node_chain(record.page)
                record.page = -1
                self._set_node(node)

    def _create_overflow(self, value: tuple) -> int:
        first = self._new_page()
        current = ItemsNode(self._conf, page=first)
        current.items = set(value[0:self._conf.item_order])

        for offset in range(self._conf.item_order, len(value), self._conf.item_order):
            coming = ItemsNode(self._conf, page=self._new_page())
            coming.items = list(value[offset:offset+self._conf.item_order])
            current.next = coming.page
            self._set_node(current)
            current = coming

        self._set_node(current)
        return first

    def _traverse_nodes(self, page: int):
        """Yield all Nodes of an item node chain."""
        coming = page
        while True:
            node = self._get_node(coming)
            yield node

            coming = node.next
            if coming is -1:
                break

    def _read_from_chain(self, page: int, count: int) -> list:
        """Collect all values of an item node chain."""
        value = list()
        rest = count
        for node in self._traverse_nodes(page):
            rest -= len(node.items)
            value += node.items

        if rest != 0:
            raise ValueError("The list length didn't match the count %s" % rest)

        return value

    def _iterate_items(self, first: int, count: int, insertions: list = list()):
        """Collect all values of an item node chain."""
        rest = count + len(insertions)
        for item in insertions:
            rest -= 1
            yield item

        for node in self._traverse_nodes(first):
            for item in node.items:
                rest -= 1
                yield item
            self._del_node(node)

        if rest != 0:
            raise ValueError("Failed reading all values, %s values left" % rest)

    def _update_items(
            self, page: int, count: int,
            insertions: list = list(), deletions: set = set()
    ):
        """Insert and delete items to/from value.

        The old overflow pages are filtered and discarded. A new overflow is created.

        Args:
            first_page (int):
                The old overflow
            count (int):
                Number of items
            insertions (list):
                Items to be inserted
            deletions (set):
                Items to be deleted, filtered

        Returns (int, int):
            New page and count

        """
        batch = list()
        cnt = 0

        for item in self._iterate_items(page, count, insertions):
            if item not in deletions:
                batch.append(item)
                cnt += 1

        first = self._create_overflow(tuple(batch))

        return first, cnt

    def _delete_node_chain(self, first_page: int):
        """Delete all Nodes in an overflow chain."""
        for node in self._traverse_nodes(first_page):
            self._del_node(node)

    def _get_value_from_record(self, record: Record) -> list:
        return self._read_from_chain(record.page, record.value)

    def traverse(self, key) -> MultiItemIterator:
        """Like get but returns an iterator."""
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except ValueError:
            return None
        else:
            count = record.value
            generator = (functools.partial(self._iterate_overflow, record.page, count)())
            return MultiItemIterator(generator, count)

    def _iterate_overflow(self, page: int, count: int):
        """Collect all values of an overflow chain."""
        size = self._conf.item_size

        for node in self._traverse_nodes(page):
            for item in node.items:
                yield item
                count -= 1

        if count != 0:
            raise ValueError("Failed reading all values, %s values left" % count)


NodeCount = namedtuple("NodeCount", "rec_cnt ref_cnt rec_node_pages ref_node_pages data_node_pages empty_node_pages unknown_node_pages")
RecordBundle = namedtuple("RecordBundle", "keys pairs")


class TreeAnalyzer:
    """Analyzer class that analyzes existing trees."""

    def __init__(self, fileobj: io.FileIO, tree_cls: Type[Tree]):
        self.fileobj = fileobj
        self.klass = tree_cls
        kind, self.root, self.empty, order, ref_order, value_size = self._load_meta(fileobj)

        if tree_cls.TREE_KIND != kind:
            raise TypeError(
                "Wrong tree class type, expected %s but got %s" % (tree_cls.TREE_KIND, bytes([kind])))

        self.conf = tree_cls.config(order, value_size)
        self.pager = Pager(fileobj, self.conf.page_size, self.conf.meta.size)

        if len(self.pager):
            if tree_cls.TREE_KIND != kind or order != self.conf.order or \
                    ref_order != self.conf.ref_order or value_size != self.conf.value_size:
                raise RuntimeError("Class configuration doesn't match saved tree.")

    def _load_meta(self, fileobj: io.FileIO) -> tuple:
        """Load meta information about tree."""
        fileobj.seek(0)
        return Tree.FORMAT_META.unpack(fileobj.read(Tree.FORMAT_META.size))

    def print_stats(self):
        """Print BTree meta and statistics information."""
        stats = self.counter()
        tmpl = "{:<24s} {}\n"
        eol = "\n"
        output = Util.headline(
            "BTree meta statistics", barrier="=") + eol + \
                 "{} {}\n".format("File:", self.fileobj.name) + \
                 "{:<24s} {} ({})\n".format("BTree type:", self.klass.__name__, self.klass.TREE_KIND.decode()) + \
                 tmpl.format("Page size:", self.conf.page_size) + \
                 tmpl.format("Value size:", self.conf.value_size) + \
                 tmpl.format("Records/page max:", self.conf.order) + \
                 tmpl.format("Record size:", self.conf.record.size) + \
                 tmpl.format("References/page max:", self.conf.ref_order) + \
                 tmpl.format("Reference size:", self.conf.reference.size) + \
                 tmpl.format("Tree root index:", self.root) + \
                 tmpl.format("Empty list index:", self.empty) + \
                 tmpl.format("Page count:", len(self.pager)) + \
                 tmpl.format("Records count:", stats.rec_cnt) + \
                 tmpl.format("References count:", stats.ref_cnt) + \
                 tmpl.format("Record node count:", len(stats.rec_node_pages)) + \
                 tmpl.format("Reference node count:", len(stats.ref_node_pages)) + \
                 tmpl.format("Data node count:", len(stats.data_node_pages)) + \
                 tmpl.format("Empty node count:", len(stats.empty_node_pages)) + \
                 tmpl.format("Unknown node count:", len(stats.unknown_node_pages)) + \
                 Util.headline("End", barrier="=") + eol

        print(output)

    def iterator(self):
        """Iterator for pages which yields (page, data)."""
        for page in range(len(self.pager)):
            yield page, self.pager[page]

    def iterate_records(self, node: RecordNode):
        """Iterator for entries in a record node"""
        for record in node.entries:
            yield record

    def kind_from_data(self, data: bytes) -> bytes:
        """Extract node kind."""
        return bytes([data[0]])

    def page_to_node(self, page: int, data: bytes) -> Node:
        """Structure node from data."""
        node = Tree.NODE_KINDS[bytes([data[0]])](self.conf, data, page)
        return node

    def records(self):
        """Iterate all records."""
        for page, data in self.iterator():
            if self.kind_from_data(data) in (b"L", b"S"):
                node = self.page_to_node(page, data)
                for record in self.iterate_records(node):
                    yield record

    def references(self):
        """Iterate all references."""
        for page, data in self.iterator():
            if self.kind_from_data(data) in (b"F", b"R"):
                node = self.page_to_node(page, data)
                for reference in self.iterate_reference(node):
                    yield reference

    def counter(self) -> NodeCount:
        """Count nodes and entries for statistics."""
        rec_cnt = 0
        ref_cnt = 0
        rec_node_pages = set()
        ref_node_pages = set()
        data_node_pages = set()
        empty_node_pages = set()
        unknown_node_pages = set()

        for page, data in self.iterator():
            kind, next_, count = Tree.FORMAT_NODE.unpack(data[:Tree.FORMAT_NODE.size])

            if kind in (b"L", b"S"):  # Records
                rec_cnt += count
                rec_node_pages.add(page)
            elif kind in (b"F", b"R"):  # References
                ref_cnt += count
                ref_node_pages.add(page)
            elif kind in (b"D",):  # Data
                data_node_pages.add(page)
            elif kind in (b"E",):  # Empty
                empty_node_pages.add(page)
            else:
                unknown_node_pages.add(page)

        return NodeCount(
            rec_cnt, ref_cnt, rec_node_pages, ref_node_pages,
            data_node_pages, empty_node_pages, unknown_node_pages
        )

    def load_pairs(self) -> RecordBundle:
        """Load key/value-pairs"""
        keys = set()
        pairs = dict()

        for record in self.records():
            keys.add(record.key)
            pairs[record.key] = record.value

        return RecordBundle(keys, pairs)

    def scanner(self, keys:set = set()) -> NodeCount:
        """Print the page where a record is found by key."""

        for page, data in self.iterator():
            if self.kind_from_data(data) in (b"L", b"S"):
                node = self.page_to_node(page, data)
                for record in self.iterate_records(node):
                    if record.key in keys:
                        print(record.key, node.page, type(node), "Is here")


class TreeRescue:
    """Rescue BTree by reading from TreeAnalyzer but inserting to new file."""

    def __init__(self, fileobj: io.FileIO, tree_cls: Type[Tree]):
        self.analyzer = TreeAnalyzer(fileobj, tree_cls)

    def rescue(self, database: io.FileIO):
        """Scans the btree and outputs a rescue copy to database."""
        print("Preparing rescue of BTree database.")

        stats = self.analyzer.counter()
        print("Preparing to copy and sort {} records.".format(stats.rec_cnt))
        tree = self.analyzer.klass.factory(
            database, self.analyzer.conf.order, self.analyzer.conf.value_size)

        iteration = 0
        stamp = time.time()
        for record in self.analyzer.records():
            iteration += 1
            tree.insert(record.key, record.value)
            if iteration % 5000 == 0:
                print("Copied and sorted {} records at {}".format(iteration, Util.hours(time.time() - stamp)))

        print("Done copying and sorting records")
        tree.pager.close()


