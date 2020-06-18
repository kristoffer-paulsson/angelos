# cython: language_level=3
#
# Copyright (c) 2020 by Kristoffer Paulsson
# This file is distributed under the terms of the MIT license.
#

import bisect
import collections
import functools
import io
import itertools
import math
import struct
import uuid
from abc import ABC, abstractmethod
from collections import namedtuple
from collections.abc import Mapping
from contextlib import ContextDecorator, AbstractContextManager
from contextvars import ContextVar
from typing import Union, Iterator, Iterable, Generator


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
    "Configuration", "order key_size value_size item_size page_size meta node reference record blob")


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
            value: bytes = None, page: int = -1
    ):
        Entry.__init__(self, conf, data)

        if not data:
            self.key = key
            self.value = value
            self.page = page

        if self.page is None:
            raise RuntimeError()

    def load(self, data: bytes):
        """Unpack data consisting of page number, key and value."""
        self.page, key, self.value = self._conf.record.unpack(data)
        self.key = uuid.UUID(bytes=key)

    def dump(self) -> bytes:
        """Packing data consisting of page number, key and value."""
        return self._conf.record.pack(self.page, self.key.bytes, self.value)


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

    def __init__(self, conf: Configuration, data: bytes = None):
        self.data = None
        Entry.__init__(self, conf, data)

    def load(self, data: bytes):
        """Load data into storage."""
        size = self._conf.blob.unpack_from(data[self._conf.blob.size:])
        self.data = bytearray(data[self._conf.blob.size: size])

    def dump(self) -> bytes:
        """Dump data from storage."""
        return self._conf.blob.pack(len(self.data)) + bytes(self.data)


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


class StackNode(Node, DataLoaderDumper):
    """Node class for nodes that are part of a stack."""

    __slots__ = []

    MAX_ENTRIES = 0

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1):
        Node.__init__(self, conf, data, page, next_)

    def load(self, data: bytes):
        """Unpack data consisting of node meta and entries."""
        if len(data) != self._conf.page_size:
            raise ValueError("Page data is not of set page size")

        kind, self.next, count = self._conf.node.unpack(data[:self._conf.node.size])

        if kind != self.NODE_KIND:
            raise TypeError("Can not load data for wrong node type")
        if count > self.MAX_ENTRIES:
            raise ValueError("Page has a higher count than the allowed order")

        if self.NODE_KIND == b"D":
            size = self._conf.blob.unpack_from(data[self._conf.node.size:])

            if (self._conf.node.size + self._conf.blob + size) > self._conf.page_size:
                raise ValueError("Blob size larger than fits in page data")

            self.blob = self.ENTRY_CLASS(self._conf, data[self._conf.node.size: self._conf.blob + size])

    def dump(self) -> bytes:
        """Packing data consisting of node meta and entries."""
        data = self._conf.node.pack(self.NODE_KIND, self.next, len(self.entries))

        if self.NODE_KIND == b"D":
            data += self.blob.dump()

        if not len(data) < self._conf.page_size:
            raise ValueError("Data larger than page size")
        else:
            data += b"\00" * (self._conf.page_size - len(data))

        return bytes(data)


class DataNode(Node):
    """Node class for arbitrary data."""

    __slots__ = ["blob"]

    NODE_KIND = b"D"
    ENTRY_CLASS = Blob
    MAX_ENTRIES = 1

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1):
        StackNode.__init__(self, conf, data, page, next_)
        self.blob = None


class EmptyNode(Node):
    """Node class for recycled nodes."""

    __slots__ = []

    NODE_KIND = b"E"

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1):
        StackNode.__init__(self, conf, data, page, next_)


class HierarchyNode(Node, DataLoaderDumper):
    """Node class for managing the btree hierarchy."""

    __slots__ = ["parent", "entries", "max", "min"]

    comparator = Comparator()

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1, parent: Node = None):
        self.parent = parent
        self.entries = list()
        self.min = 0
        Node.__init__(self, conf, data, page)
        self.max = self._conf.order

    def is_not_full(self) -> bool:
        """Can entries be added."""
        return self.length() < self.max

    def is_not_empty(self) -> bool:
        """Can entries be deleted."""
        return self.length() > self.min

    def least_entry(self):
        """Get least entry"""
        return self.entries[0]

    def least_key(self):
        """Get least key"""
        return self.least_entry().key

    def largest_entry(self):
        """Get largest entry"""
        return self.entries[-1]

    def largest_key(self):
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
        HierarchyNode.comparator.key = key
        i = bisect.bisect_left(self.entries, HierarchyNode.comparator)

        if i >= len(self.entries) or self.entries[i] != HierarchyNode.comparator:
            raise ValueError('No entry for key {}'.format(key))

        return i

    def split_entries(self) -> list:
        """Split an entry in two halves and return half of all entries."""
        length = len(self.entries)
        if length > 4:
            RuntimeError("At least 4 entries in order to split a node")
        rest = self.entries[length // 2:]
        self.entries = self.entries[:length // 2]
        return rest

    def load(self, data: bytes):
        """Unpack data consisting of node meta and entries."""
        if len(data) != self._conf.page_size:
            raise ValueError("Page data is not of set page size")

        kind, self.next, count = self._conf.node.unpack(data[:self._conf.node.size])

        if kind != self.NODE_KIND:
            raise TypeError("Can not load data for wrong node type")
        if count > self._conf.order:
            raise ValueError("Page has a higher count than the current order")

        size = self._conf.record.size if self.NODE_KIND in (b"C", b"S") else self._conf.reference.size

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
            self.min, self.max, self.parent
        )


class RecordNode(HierarchyNode):
    """Node class that is used as leaf node of records."""

    __slots__ = []

    NODE_KIND = b"C"
    ENTRY_CLASS = Record

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, next_: int = -1, parent: Node = None):
        HierarchyNode.__init__(self, conf, data, page, next_, parent)
        self.min = math.ceil(self._conf.order / 2) - 1


class StartNode(RecordNode):
    """When there only is one node this is the root."""

    __slots__ = []

    NODE_KIND = b"S"

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):
        RecordNode.__init__(self, conf, data, page, parent=parent)
        self.min = 0

    def convert(self):
        """Convert start node to normal node."""
        node = RecordNode(self._conf, page=self.page)
        node.entries = self.entries
        return node


class ReferenceNode(HierarchyNode):
    """Node class for holding references higher up than leaf nodes."""

    __slots__ = []

    ENTRY_CLASS = Reference

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):
        HierarchyNode.__init__(self, conf, data, page, parent=parent)


class StructureNode(ReferenceNode):
    """Node class for references that isn't root node."""

    __slots__ = []

    NODE_KIND = b"F"

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):

        ReferenceNode.__init__(self, conf, data, page, parent)
        self.min = math.ceil(self._conf.order / 2)

    def length(self) -> int:
        """Entries count."""
        return len(self.entries) + 1 if self.entries else 0

    def insert_entry(self, entry: Reference):
        """Make sure that after of a reference matches before of the next one.

        Probably very inefficient approach.
        """
        HierarchyNode.insert_entry(self, entry)
        i = self.entries.index(entry)
        if i > 0:
            prev = self.entries[i - 1]
            prev.after = entry.before

        if i + 1 > len(self.entries):
            self.entries[i + 1].before = entry.after

        # try:
        #    next_ = self.entries[i + 1]
        # except IndexError:
        #    pass
        # else:
        #    next_.before = entry.after


class RootNode(ReferenceNode):
    """When there is several nodes this is the root."""

    __slots__ = []

    NODE_KIND = b"R"

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, parent: Node = None):
        ReferenceNode.__init__(self, conf, data, page, parent)
        self.min = 2

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

        length = self._fd.seek(0, io.SEEK_END)
        if length:
            if self.__size % length:
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

    NODE_KINDS = {
        DataNode.NODE_KIND: DataNode,
        EmptyNode.NODE_KIND: EmptyNode,
        RecordNode.NODE_KIND: RecordNode,
        StartNode.NODE_KIND: StartNode,
        StructureNode.NODE_KIND: StructureNode,
        RootNode.NODE_KIND: RootNode
    }

    def __init__(self, fileobj: io.FileIO, order: int, key_size: int, value_size: int):
        self.__root = -1  # Page number for tree root node
        self.__empty = -1  # Page number of recycled page stack start

        self._conf = self._config(order, key_size, value_size)
        self._pager = Pager(fileobj, self._conf.page_size, self._conf.meta.size)

        if len(self._pager):
            o, ks, vs = self._meta_load()
            if o != order or ks != key_size or vs != value_size:
                raise RuntimeError("Class configuration doesn't match saved tree.")
        else:
            self._initialize()

    def _config(self, order: int, key_size: int, value_size: int) -> Configuration:
        """Generate configuration class."""

        if order < 4:
            raise OSError("Order can never be less than 4.")

        meta = struct.Struct("!iiIII")  # Meta, root, empty, order, key_size, value_size
        node = struct.Struct("!siI")  # Node: type, next, count
        reference = struct.Struct("!II" + str(key_size) + "s")  # Reference, before, after, key
        record = struct.Struct("!I" + str(key_size) + "s" + str(value_size) + "s")  # Record: page, key, value
        blob = struct.Struct("!I")

        return Configuration(
            order, key_size, value_size, value_size, order * record.size + node.size, meta,
            node, reference, record, blob
        )

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
        self.__root, self.__empty, order, key_size, value_size = self._conf.meta.unpack()
        return order, key_size, value_size

    def _meta_save(self):
        """Save meta-data."""
        self._pager.meta(self._conf.meta.pack(
            self.__root, self.__empty, self._conf.order, self._conf.key_size, self._conf.value_size))

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
            node = self.get_node(self.__empty)
            self.__empty = node.next
            self.meta_save()
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

    def _left_record_node(self) -> Union[StartNode, RecordNode]:
        node = self.__root_node()
        while not isinstance(node, (StartNode, RecordNode)):
            node = self._get_node(node.least_entry().before)
        return node

    def _pairs(self, iterable: Iterable):
        a, b = itertools.tee(iterable)
        next(b, None)
        return zip(a, b)

    def _search(self, key: uuid.UUID, node: Node) -> Node:
        if isinstance(node, (StartNode, RecordNode)):
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
            node = self._search(part.start, self.__root_node())

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

    def _cleave_node(self, node: HierarchyNode):
        parent = node.parent
        sliver = RecordNode(self._conf, page=self._new_page(), next_=node.next)
        entries = node.split_entries()
        sliver.entries = entries
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

    def _cleave_parent(self, node: Node):
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


class SimpleBTree(Tree):
    """BTree that handles single item values."""

    def _config(self, order: int, key_size: int, value_size: int) -> Configuration:
        """Generate configuration class."""

        if order < 4:
            raise OSError("Order can never be less than 4.")

        meta = struct.Struct("!iiIII")  # Meta, root, empty, order, key_size, value_size
        node = struct.Struct("!siI")  # Node: type, next, count
        reference = struct.Struct("!ii" + str(key_size) + "s")  # Reference, before, after, key
        record = struct.Struct("!i" + str(key_size) + "s" + str(value_size) + "s")  # Record: page, key, value
        blob = struct.Struct("!I")

        return Configuration(
            order, key_size, value_size, 0, order * record.size + node.size, meta,
            node, reference, record, blob
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
        except ValueError:
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
        except ValueError:
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
        except ValueError:
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
        except ValueError:
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

    def _config(self, order: int, key_size: int, value_size: int) -> Configuration:
        """Generate configuration class."""

        if order < 4:
            raise OSError("Order can never be less than 4.")

        meta = struct.Struct("!iiIII")  # Meta, root, empty, order, key_size, value_size
        node = struct.Struct("!siI")  # Node: type, next, count
        reference = struct.Struct("!ii" + str(key_size) + "s")  # Reference, before, after, key
        # record = struct.Struct("!i" + str(key_size) + "s" + str(4) + "s")  # Record: page, key, value
        record = struct.Struct("!i" + str(key_size) + "sI")  # Record: page, key, value
        blob = struct.Struct("!I")

        return Configuration(
            order, key_size, 4, value_size, order * record.size + node.size, meta,
            node, reference, record, blob
        )

    def insert(self, key: uuid.UUID, value: Union[set, list]):
        """Insert key and values into the tree.

        :param key:
        :param value:
        :return:
        """

        # with self._mem.write_transaction:
        node = self._search(key, self._root_node())

        # Check if a record with the key already exists
        try:
            node.get_entry(key)
        except ValueError:
            length = len(value)
            value = tuple(value)
            page = self._create_overflow(value) if value else None

            record = self.Record(
                self._conf,
                key=key,
                # value=length.to_bytes(4, byteorder="big"),
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

        # with self._mem.write_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except ValueError:
            raise ValueError("Record to update doesn't exist")
        else:
            # length = record.value if type(record.value) is int else int.from_bytes(record.value, ENDIAN)
            # length = int.from_bytes(record.value, ENDIAN)
            length = record.value
            if length:
                record.page, record.value = self._update_overflow(
                    record.page,
                    length,
                    insertions,
                    deletions
                )
            else:
                length = len(insertions)
                # record.value = length.to_bytes(4, byteorder="big")
                record.value = length
                record.page = self._create_overflow(tuple(insertions))

            self._set_node(node)

    def get(self, key: uuid.UUID) -> list:
        """Get values from the tree using key.

        :param key:
        :return:
        """
        # with self._mem.read_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except ValueError:
            return list()
        else:
            # length = int.from_bytes(record.value, ENDIAN)
            length = record.value
            if length:
                return self._get_value_from_record(record)
            else:
                return list()

    def delete(self, key: uuid.UUID):
        """Delete entry from the tree using key.

        :param key:
        :return:
        """
        # with self._mem.read_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except ValueError:
            pass
        else:
            # length = int.from_bytes(record.value, ENDIAN)
            length = record.value
            if length:
                self._delete_overflow(record.page)
            node.remove_entry(key)
            self._set_node(node)

    def clear(self, key: uuid.UUID):
        """Clear all values from entry in the tree.

        :param key:
        :return:
        """
        # with self._mem.read_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except ValueError:
            pass
        else:
            # length = int.from_bytes(record.value, ENDIAN)
            length = record.value
            if length:
                self._delete_overflow(record.page)
                record.page = None
                self._set_node(node)

    def _create_overflow(self, value: tuple) -> int:
        size = self._conf.item_size
        count = len(value)

        batch = (self._conf.page_size - self._conf.node.size + self._conf.blob.size) // size
        batch_cnt = count // batch
        batch_cnt += 1 if bool(count % batch) else 0

        first_page = self._new_page()
        next_page = first_page

        for batch_idx in range(batch_cnt):
            current_page = next_page

            chunk = value[batch_idx * batch:batch_idx * batch + batch]
            data_write = b""
            for item in chunk:
                data_write += item

            if batch_idx == batch_cnt - 1:
                next_page = None
            else:
                next_page = self._new_page()

            data_node = DataNode(self._conf, page=current_page, next_=next_page)
            data_node.blob = Blob(data=data_write)
            self._set_node(data_node)

        return first_page

    def _traverse_overflow(self, first_page: int):
        """Yield all Nodes of an overflow chain."""
        next_page = first_page
        while True:
            data_node = self._get_node(next_page)
            yield data_node

            next_page = data_node.next_page
            if next_page is None:
                break

    def _read_from_overflow(self, first_page: int, count: int) -> list:
        """Collect all values of an overflow chain."""
        size = self._conf.item_size

        batch = (self._conf.page_size - self._conf.node.size + self._conf.blob.size) // size
        batch_cnt = count // batch
        batch_cnt += 1 if bool(count % batch) else 0

        value = list()
        rest = count
        for data_node in self._traverse_overflow(first_page):

            chunk = data_node.least_entry().data[0:batch * size]
            for item_idx in range(min(batch, rest)):
                item = chunk[item_idx * size:item_idx * size + size]
                value.append(item)
            rest -= batch

        if len(value) != count:
            raise ValueError("The list length didn't match the count")

        return value

    def _iterate_from_overflow(self, first_page: int, count: int, insertions: list = list()):
        """Collect all values of an overflow chain."""
        size = self._conf.item_size

        for item in insertions:
            yield item

        for data_node in self._traverse_overflow(first_page):
            data = data_node.smallest_entry.data
            length = len(data)
            for item_offset in range(0, length, size):
                yield data[item_offset:item_offset + size]
                count -= 1
            self._del_node(data_node)

        if count != 0:
            raise ValueError("Failed reading all values, %s values left" % count)

    def _add_overflow(self, next_page: int, chunk: list, is_last: bool = False) -> int:
        size = self._conf.item_size
        current_page = next_page

        data = b""
        for item in chunk:
            data += item

        if is_last:
            next_page = None
        else:
            next_page = self._new_page()

        data_node = DataNode(self._conf, page=current_page, next_=next_page)
        data_node.blob = Blob(data=data)
        self._set_node(data_node)

        return next_page

    def _update_overflow(
            self, first_page: int, count: int,
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
        size = self._conf.item_size

        batch = (self._conf.page_size - self._conf.node.size + self._conf.blob.size) // size
        batch_cnt = count // batch
        batch_cnt += 1 if bool(count % batch) else 0

        new_first_page = self._new_page()
        next_page = new_first_page

        chunk = list()
        length = 0
        new_count = 0
        for item in self._iterate_from_overflow(first_page, count, insertions):
            if item not in deletions:
                chunk.append(item)
                length += 1
                new_count += 1

            if length == batch:
                next_page = self._add_overflow(next_page, chunk)
                chunk = list()
                length = 0

        if length > 0:
            self._add_overflow(next_page, chunk, True)

        return new_first_page, new_count

    def _delete_overflow(self, first_page: int):
        """Delete all Nodes in an overflow chain."""
        for node in self._traverse_overflow(first_page):
            self._del_node(node)

    def _get_value_from_record(self, record: Record) -> list:
        # return self._read_from_overflow(record.page, int.from_bytes(record.value, ENDIAN))
        return self._read_from_overflow(record.page, record.value)

    def traverse(self, key) -> MultiItemIterator:
        """Like get but returns an iterator."""
        # with self._mem.read_transaction:
        node = self._search(key, self._root_node())
        try:
            record = node.get_entry(key)
        except ValueError:
            return None
        else:
            # count = int.from_bytes(record.value, ENDIAN)
            count = record.value
            generator = (functools.partial(self._iterate_overflow, record.page, count)())
            return MultiItemIterator(generator, count)

    def _iterate_overflow(self, first_page: int, count: int):
        """Collect all values of an overflow chain."""
        size = self._conf.item_size

        for data_node in self._traverse_overflow(first_page):
            data = data_node.least_entry().data
            length = len(data)
            for item_offset in range(0, length, size):
                yield data[item_offset:item_offset + size]
                count -= 1

        if count != 0:
            raise ValueError("Failed reading all values, %s values left" % count)
