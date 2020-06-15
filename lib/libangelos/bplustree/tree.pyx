# cython: language_level=3
#
# Copyright (c) 2017 by Nicolas Le Manchet
# Copyright (c) 2020 by Kristoffer Paulsson
# This file is distributed under the terms of the MIT license.
#

import collections
import enum
import functools
import io
import itertools
import math
import os
import platform
import bisect
import struct
import uuid

import cachetools
import rwlock

import logging
from abc import ABC, abstractmethod
from collections import namedtuple
from collections.abc import Mapping
from functools import lru_cache
from typing import Optional, Union, Iterator, Iterable, Generator, Tuple


class DataLoaderDumper(ABC):
    """Data load/dump data base class."""

    @abstractmethod
    def load(self, data: bytes):
        pass

    @abstractmethod
    def dump(self) -> bytes:
        pass


Configuration = namedtuple("Configuration", "order key_size value_size page_size meta node reference record")


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


class Entry(ABC, DataLoaderDumper):
    """Entry base class."""
    __slots__ = []

    def __init__(self, conf: Configuration, data: bytes = None):
        self._conf = conf
        self._data = data

        if data:
            self.load()


class Record(Entry, Comparable):
    """Record entry using key/value-pair."""

    __slots__ = ["key", "value", "page"]

    def __init__(self, conf: Configuration, data: bytes = None, key:uuid.UUID = None, value: bytes = None, page: int = None):
        Entry.__init__(self, conf, data)

        if not data:
            self.key = key
            self.value = value
            self.page = page

    def load(self, data: bytes):
        """Unpack data consisting of page number, key and value."""
        self.page, self.key, self.value = self._conf.record.unpack()

    def dump(self) -> bytes:
        """Packing data consisting of page number, key and value."""
        return self._conf.record.pack(self.page, self.key, self.value)


class Reference(Entry, Comparable):
    """Reference entry for internal structure."""

    __slots__ = ["key", "before", "after"]

    def __init__(self, conf: Configuration, data: bytes = None, key:uuid.UUID = None, before: int = None, after: int = None):
        Entry.__init__(self, conf, data)

        if not data:
            self.key = key
            self.before = before
            self.after = after

    def load(self, data: bytes):
        """Unpack data consisting of before, after and key."""
        self.before, self.after, self.key = self._conf.reference.unpack()

    def dump(self) -> bytes:
        """Packing data consisting of before, after and key."""
        return self._conf.reference.pack(self.before, self.after, self.key)


class Blob(Entry):
    """Blob entry for opaque data."""

    __slots__ = ['data']

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


class Node(ABC, DataLoaderDumper):
    """Node base class"""

    __slots__ = ["_conf", "data", "page", "next"]

    NODE_KIND = b""
    ENTRY_CLASS = None

    def __init__(self, conf: Configuration, data: bytes, page: int, next_: int = None):
        self._conf = conf
        self.page = page # Current page index
        self.next = next_ # Next node page index

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

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = None):
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

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = None):
        StackNode.__init__(self, conf, data, page, next_)
        self.blob = None


class EmptyNode(Node):
    """Node class for recycled nodes."""

    __slots__ = []

    NODE_KIND = b"E"

    def __init__(self, conf: Configuration, data: bytes = None, page: int = None, next_: int = None):
        StackNode.__init__(self, conf, data, page, next_)


class HierarchyNode(Node):
    """Node class for managing the btree hierarchy."""

    __slots__ = ["parent", "entries", "max", "min"]

    comparator = Comparator()

    def __init__(
            self, conf: Configuration, data: bytes = None, page: int = None, next_: int = None, parent: Node = None):

        Node.__init__(self, conf, data, page)
        self.parent = parent
        self.entries = list()
        self.min = 0
        self.max = self._conf.order

    def is_full(self) -> bool:
        """Can entries be added."""
        return self.length() < self.max

    def is_empty(self) -> bool:
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
        return self.entries[self._find_entry_index(key)]

    def _find_by_key(self, key: uuid.UUID) -> int:
        HierarchyNode.comparator.key = key
        i = bisect.bisect_left(self.entries, HierarchyNode.comparator)
        if i != len(self.entries) and self.entries[i] == HierarchyNode.comparator:
            return i
        raise ValueError('No entry for key {}'.format(key))

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

        for offset in range(self._conf.node.size, count, size):
            self.entries.append(self.ENTRY_CLASS(self._conf, data=data[offset:size]))

    def dump(self) -> bytes:
        """Packing data consisting of node meta and entries."""
        data = self._conf.node.pack(self.NODE_KIND, self.next, len(self.entries))

        for entry in self.entries:
            data += entry.dump()

        if not len(data) < self._conf.page_size:
            raise ValueError("Data larger than page size")
        else:
            data += b"\00" * (self._conf.page_size - len(data))

        return bytes(data)

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
            self, conf: Configuration, data: bytes = None, page: int = None, next_: int = None, parent: Node = None):

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
        rec = RecordNode(self._conf, page=self.page)
        rec.entries = self.entries
        return rec


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
        structure = StructureNode(self._conf, page=self.page)
        structure.entries = self.entries
        return structure


class Pager(Mapping):
    """Pager that wraps pages written to a file object, indexed like a list."""

    def __init__(self, fileobj: io.FileIO, size: int, meta: int = 0):
        self._fd = fileobj
        self.__size = size
        self.__meta = meta
        self.__pages = 0

        length = self._fd.seek(0, io.SEEK_END)
        if self.__size % length:
            raise OSError("File of uneven length compared to page size of %s bytes" % self.__size)
        self.__pages = length // self.__size

    @lru_cache(max_size=64, typed=True)
    def __getitem__(self, k: int) -> bytes:
        if not k < self.__pages:
            raise KeyError("Invalid key")

        self._fd.seek(k * self.__size + self.__meta)
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
        if len(data) == self.__size:
            raise ValueError("Data size different from page size.")

        self._fd.seek(index * self.__size + self.__meta)
        self._fd.write(data)

    @lru_cache(max_size=64, typed=True)
    def read(self, index: int):
        """Read a page of data from an existing index."""
        if not index < self.__pages:
            raise IndexError("Out of bounds")

        self._fd.seek(index * self.__size + self.__meta)
        return self._fd.read(self.__size)

    def append(self, data: Union[bytes, bytearray]) -> int:
        """Append a page of data to the end of the list."""
        if len(data) == self.__size:
            raise ValueError("Data size different from page size.")

        self._fd.seek(0, io.SEEK_END)
        self._fd.write(data)
        self.__pages += 1
        return self.__pages - 1


class Memory:
    """Memory for tree structure."""

    NODE_KINDS = {
        DataNode.NODE_KIND: DataNode,
        EmptyNode.NODE_KIND: EmptyNode,
        RecordNode.NODE_KIND: RecordNode,
        StartNode.NODE_KIND: StartNode,
        StructureNode.NODE_KIND: StructureNode,
        RootNode.NODE_KIND: RootNode
    }

    def __init__(self, fileobj: io.FileIO, data_size: int, order: int = 50, meta: tuple = tuple(None, None)):
        if order < 4:
            raise OSError("Order can never be less than 4.")

        self._data_size = data_size
        self._order = order
        self._pager = Pager(fileobj, data_size * order)

        # Metadata
        self.__root = None # Page number for tree root node
        self.__empty = None # Page number of recycled page stack start

    def get_node(self, page: int):
        """Loads node data from the pager and deserializes it."""

        data = self._pager[page]
        kind = data[0]

        if kind not in self.NODE_KINDS:
            raise TypeError("Unknown node type: %s" % kind)

        return self.NODE_KINDS[kind](self._conf, data=data, page=page)

    def set_node(self, node: Node):
        self._pager[node.page] = bytes(node)

    def del_node(self, node: Node):
        self.__recycle(node.page)

    def del_page(self, page: int):
        self.__recycle(page)

    def __recycle(self, page: int):
        self.set_node(EmptyNode(self._tree_conf, page=page, next_=self.__empty))
        self.__empty = page


class Tree:
    def __init__(self):
        pass

    def conf(self, order: int, key_size: int, value_size: int) -> tuple:
        meta = struct.Struct("!")  # Meta
        node = struct.Struct("!sII")  # Node: type, next, count
        reference = struct.Struct("!II" + str(key_size) + "s")  # Reference, before, after, key
        record = struct.Struct("!I" + str(key_size) + "s" + str(value_size) + "s")  # Record: page, key, value
        blob = struct.Struct("!I")

        return Configuration(
            order,
            key_size,
            value_size,
            order * record.size + node.size,
            meta,
            node,
            reference,
            record,
            blob
        )


# Endianess for storing numbers
ENDIAN = 'big'

# Bytes used for storing references to pages
# Can address 16 TB of memory with 4 KB pages
PAGE_REFERENCE_BYTES = 4

# Bytes used for storing the type of the node in page header
NODE_TYPE_BYTES = 1

# Bytes used for storing the length of the page payload in page header
USED_PAGE_LENGTH_BYTES = 3

# Bytes used for storing the length of the key or value payload in record
# header. Limits the maximum length of a key or value to 64 KB.
USED_KEY_LENGTH_BYTES = 2
USED_VALUE_LENGTH_BYTES = 2

# Max 256 types of frames
FRAME_TYPE_BYTES = 1

# Bytes used for storing general purpose integers like file metadata
OTHERS_BYTES = 4


TreeConf = namedtuple('TreeConf', [
    'page_size',  # Size of a page within the tree in bytes
    'order',  # Branching factor of the tree
    'key_size',  # Maximum size of a key in bytes
    'value_size',  # Maximum size of a value in bytes
    'item_size',  # Size of items in multi item values
    'serializer',  # Instance of a Serializer
])


class ReachedEndOfFile(Exception):
    """Read a file until its end."""


def pairwise(iterable: Iterable):
    """Iterate over elements two by two.

    s -> (s0,s1), (s1,s2), (s2, s3), ...
    """
    a, b = itertools.tee(iterable)
    next(b, None)
    return zip(a, b)

def iter_slice(iterable: bytes, n: int):
    """Yield slices of size n and says if each slice is the last one.

    s -> (b'123', False), (b'45', True)
    """
    start = 0
    stop = start + n
    final_offset = len(iterable)

    while True:
        if start >= final_offset:
            break

        rv = iterable[start:stop]
        start = stop
        stop = start + n
        yield rv, start >= final_offset


def open_file_in_dir(path: str) -> Tuple[io.FileIO, Optional[int]]:
    """Open a file and its directory.

    The file is opened in binary mode and created if it does not exist.
    Both file descriptors must be closed after use to prevent them from
    leaking.

    On Windows, the directory is not opened, as it is useless.
    """
    directory = os.path.dirname(path)
    if not os.path.isdir(directory):
        raise ValueError('No directory {}'.format(directory))

    if not os.path.exists(path):
        file_fd = open(path, mode='x+b', buffering=0)
    else:
        file_fd = open(path, mode='r+b', buffering=0)

    if platform.system() == 'Windows':
        # Opening a directory is not possible on Windows, but that is not
        # a problem since Windows does not need to fsync the directory in
        # order to persist metadata
        dir_fd = None
    else:
        dir_fd = os.open(directory, os.O_RDONLY)

    return file_fd, dir_fd

def write_to_file(file_fd: io.FileIO, data: bytes):
    length_to_write = len(data)
    written = 0
    while written < length_to_write:
        written += file_fd.write(data[written:])

def read_from_file(file_fd: io.FileIO, start: int, stop: int) -> bytes:
    length = stop - start
    assert length >= 0
    to = file_fd.seek(start)
    assert to == start
    data = file_fd.read(length)
    if data == b'':
        raise ReachedEndOfFile('Read until the end of file')
    assert len(data) == length

    return data


class Serializer(ABC):
    __slots__ = []

    @abstractmethod
    def serialize(self, obj: object, key_size: int) -> bytes:
        """Serialize a key to bytes."""

    @abstractmethod
    def deserialize(self, data: bytes) -> object:
        """Create a key object from bytes."""

    def __repr__(self):
        return '{}()'.format(self.__class__.__name__)


class IntSerializer(Serializer):
    __slots__ = []

    def serialize(self, obj: int, key_size: int) -> bytes:
        return obj.to_bytes(key_size, ENDIAN)

    def deserialize(self, data: bytes) -> int:
        return int.from_bytes(data, ENDIAN)


class StrSerializer(Serializer):
    __slots__ = []

    def serialize(self, obj: str, key_size: int) -> bytes:
        rv = obj.encode(encoding='utf-8')
        if len(rv) > key_size:
            raise ValueError("String longer than key size")
        return rv

    def deserialize(self, data: bytes) -> str:
        return data.decode(encoding='utf-8')


class UUIDSerializer(Serializer):
    __slots__ = []

    def serialize(self, obj: uuid.UUID, key_size: int) -> bytes:
        return obj.bytes

    def deserialize(self, data: bytes) -> uuid.UUID:
        return uuid.UUID(bytes=data)


NOT_LOADED = object()


class Entry(ABC):
    __slots__ = []

    @abstractmethod
    def load(self, data: bytes):
        """Deserialize data into an object."""

    @abstractmethod
    def dump(self) -> bytes:
        """Serialize object to data."""


class ComparableEntry(Entry):
    """Entry that can be sorted against other entries based on their key."""

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


class Record(ComparableEntry):
    """A container for the actual data the tree stores."""

    __slots__ = ['_tree_conf', 'length', '_key', '_value', '_overflow_page',
                 '_data']

    def __init__(self, tree_conf: TreeConf, key=None,
                 value: Optional[bytes] = None, data: Optional[bytes] = None,
                 overflow_page: Optional[int] = None):
        self._tree_conf = tree_conf
        self.length = (
                USED_KEY_LENGTH_BYTES + self._tree_conf.key_size +
                USED_VALUE_LENGTH_BYTES + self._tree_conf.value_size +
                PAGE_REFERENCE_BYTES
        )
        self._data = data

        if self._data:
            self._key = NOT_LOADED
            self._value = NOT_LOADED
            self._overflow_page = NOT_LOADED
        else:
            self._key = key
            self._value = value
            self._overflow_page = overflow_page

    @property
    def key(self):
        if self._key == NOT_LOADED:
            self.load(self._data)
        return self._key

    @key.setter
    def key(self, v):
        self._data = None
        self._key = v

    @property
    def value(self):
        if self._value == NOT_LOADED:
            self.load(self._data)
        return self._value

    @value.setter
    def value(self, v):
        self._data = None
        self._value = v

    @property
    def overflow_page(self):
        if self._overflow_page == NOT_LOADED:
            self.load(self._data)
        return self._overflow_page

    @overflow_page.setter
    def overflow_page(self, v):
        self._data = None
        self._overflow_page = v

    def load(self, data: bytes):
        assert len(data) == self.length

        end_used_key_length = USED_KEY_LENGTH_BYTES
        used_key_length = int.from_bytes(data[0:end_used_key_length], ENDIAN)
        assert 0 <= used_key_length <= self._tree_conf.key_size

        end_key = end_used_key_length + used_key_length
        self._key = self._tree_conf.serializer.deserialize(
            data[end_used_key_length:end_key]
        )

        start_used_value_length = (
                end_used_key_length + self._tree_conf.key_size
        )
        end_used_value_length = (
                start_used_value_length + USED_VALUE_LENGTH_BYTES
        )
        used_value_length = int.from_bytes(
            data[start_used_value_length:end_used_value_length], ENDIAN
        )
        assert 0 <= used_value_length <= self._tree_conf.value_size

        end_value = end_used_value_length + used_value_length

        start_overflow = end_used_value_length + self._tree_conf.value_size
        end_overflow = start_overflow + PAGE_REFERENCE_BYTES
        overflow_page = int.from_bytes(
            data[start_overflow:end_overflow], ENDIAN
        )

        if overflow_page:
            self._overflow_page = overflow_page
            self._value = None
        else:
            self._overflow_page = None
            self._value = data[end_used_value_length:end_value]

    def dump(self) -> bytes:

        if self._data:
            return self._data

        # assert self._value is None or self._overflow_page is None
        key_as_bytes = self._tree_conf.serializer.serialize(
            self._key, self._tree_conf.key_size
        )
        used_key_length = len(key_as_bytes)
        overflow_page = self._overflow_page or 0
        if overflow_page:
            value = b''
        else:
            value = self._value
        used_value_length = len(value)

        data = (
                used_key_length.to_bytes(USED_VALUE_LENGTH_BYTES, ENDIAN) +
                key_as_bytes +
                bytes(self._tree_conf.key_size - used_key_length) +
                used_value_length.to_bytes(USED_VALUE_LENGTH_BYTES, ENDIAN) +
                value +
                bytes(self._tree_conf.value_size - used_value_length) +
                overflow_page.to_bytes(PAGE_REFERENCE_BYTES, ENDIAN)
        )
        return data

    def __repr__(self):
        if self.overflow_page:
            return '<Record: {} overflowing value>'.format(self.key)
        if self.value:
            return '<Record: {} value={}>'.format(
                self.key, self.value[0:16]
            )
        return '<Record: {} unknown value>'.format(self.key)


class Reference(ComparableEntry):
    """A container for a reference to other nodes."""

    __slots__ = ['_tree_conf', 'length', '_key', '_before', '_after', '_data']

    def __init__(self, tree_conf: TreeConf, key=None, before=None, after=None,
                 data: bytes = None):
        self._tree_conf = tree_conf
        self.length = (
                2 * PAGE_REFERENCE_BYTES +
                USED_KEY_LENGTH_BYTES +
                self._tree_conf.key_size
        )
        self._data = data

        if self._data:
            self._key = NOT_LOADED
            self._before = NOT_LOADED
            self._after = NOT_LOADED
        else:
            self._key = key
            self._before = before
            self._after = after

    @property
    def key(self):
        if self._key == NOT_LOADED:
            self.load(self._data)
        return self._key

    @key.setter
    def key(self, v):
        self._data = None
        self._key = v

    @property
    def before(self):
        if self._before == NOT_LOADED:
            self.load(self._data)
        return self._before

    @before.setter
    def before(self, v):
        self._data = None
        self._before = v

    @property
    def after(self):
        if self._after == NOT_LOADED:
            self.load(self._data)
        return self._after

    @after.setter
    def after(self, v):
        self._data = None
        self._after = v

    def load(self, data: bytes):
        assert len(data) == self.length
        end_before = PAGE_REFERENCE_BYTES
        self._before = int.from_bytes(data[0:end_before], ENDIAN)

        end_used_key_length = end_before + USED_KEY_LENGTH_BYTES
        used_key_length = int.from_bytes(
            data[end_before:end_used_key_length], ENDIAN
        )
        assert 0 <= used_key_length <= self._tree_conf.key_size

        end_key = end_used_key_length + used_key_length
        self._key = self._tree_conf.serializer.deserialize(
            data[end_used_key_length:end_key]
        )

        start_after = end_used_key_length + self._tree_conf.key_size
        end_after = start_after + PAGE_REFERENCE_BYTES
        self._after = int.from_bytes(data[start_after:end_after], ENDIAN)

    def dump(self) -> bytes:

        if self._data:
            return self._data

        assert isinstance(self._before, int)
        assert isinstance(self._after, int)

        key_as_bytes = self._tree_conf.serializer.serialize(
            self._key, self._tree_conf.key_size
        )
        used_key_length = len(key_as_bytes)

        data = (
                self._before.to_bytes(PAGE_REFERENCE_BYTES, ENDIAN) +
                used_key_length.to_bytes(USED_VALUE_LENGTH_BYTES, ENDIAN) +
                key_as_bytes +
                bytes(self._tree_conf.key_size - used_key_length) +
                self._after.to_bytes(PAGE_REFERENCE_BYTES, ENDIAN)
        )
        return data

    def __repr__(self):
        return '<Reference: key={} before={} after={}>'.format(
            self.key, self.before, self.after
        )


class OpaqueData(Entry):
    """Entry holding opaque data."""

    __slots__ = ['data']

    def __init__(self, tree_conf: TreeConf = None, data: bytes = None):
        self.data = data

    def load(self, data: bytes):
        self.data = data

    def dump(self) -> bytes:
        return self.data

    def __repr__(self):
        return '<OpaqueData: {}>'.format(self.data)


class BNode(ABC):
    __slots__ = ['_tree_conf', 'entries', 'page', 'parent', 'next_page']

    # Attributes to redefine in inherited classes
    _node_type_int = 0
    max_children = 0
    min_children = 0
    _entry_class = None

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, parent: 'BNode' = None, next_page: int = None):
        self._tree_conf = tree_conf
        self.entries = list()
        self.page = page
        self.parent = parent
        self.next_page = next_page
        if data:
            self.load(data)

    def load(self, data: bytes):
        assert len(data) == self._tree_conf.page_size
        end_used_page_length = NODE_TYPE_BYTES + USED_PAGE_LENGTH_BYTES
        used_page_length = int.from_bytes(
            data[NODE_TYPE_BYTES:end_used_page_length], ENDIAN
        )
        end_header = end_used_page_length + PAGE_REFERENCE_BYTES
        self.next_page = int.from_bytes(
            data[end_used_page_length:end_header], ENDIAN
        )
        if self.next_page == 0:
            self.next_page = None

        if self._entry_class is None:
            # For Nodes that cannot hold Entries
            return

        try:
            # For Nodes that can hold multiple sized Entries
            entry_length = self._entry_class(self._tree_conf).length
        except AttributeError:
            # For Nodes that can hold a single variable sized Entry
            entry_length = used_page_length - end_header

        for start_offset in range(end_header, used_page_length, entry_length):
            entry_data = data[start_offset:start_offset + entry_length]
            entry = self._entry_class(self._tree_conf, data=entry_data)
            self.entries.append(entry)

    def dump(self) -> bytearray:
        data = bytearray()
        for record in self.entries:
            data.extend(record.dump())

        # used_page_length = len(header) + len(data), but the header is
        # generated later
        used_page_length = len(data) + 4 + PAGE_REFERENCE_BYTES
        assert 0 < used_page_length <= self._tree_conf.page_size
        assert len(data) <= self.max_payload

        next_page = 0 if self.next_page is None else self.next_page
        header = (
                self._node_type_int.to_bytes(1, ENDIAN) +
                used_page_length.to_bytes(3, ENDIAN) +
                next_page.to_bytes(PAGE_REFERENCE_BYTES, ENDIAN)
        )

        data = bytearray(header) + data

        padding = self._tree_conf.page_size - used_page_length
        assert padding >= 0
        data.extend(bytearray(padding))
        assert len(data) == self._tree_conf.page_size

        return data

    @property
    def max_payload(self) -> int:
        """Size in bytes of serialized payload a Node can carry."""
        return (
                self._tree_conf.page_size - 4 - PAGE_REFERENCE_BYTES
        )

    @property
    def can_add_entry(self) -> bool:
        return self.num_children < self.max_children

    @property
    def can_delete_entry(self) -> bool:
        return self.num_children > self.min_children

    @property
    def smallest_key(self):
        return self.smallest_entry.key

    @property
    def smallest_entry(self):
        return self.entries[0]

    @property
    def biggest_key(self):
        return self.biggest_entry.key

    @property
    def biggest_entry(self):
        return self.entries[-1]

    @property
    def num_children(self) -> int:
        """Number of entries or other nodes connected to the node."""
        return len(self.entries)

    def pop_smallest(self) -> Entry:
        """Remove and return the smallest entry."""
        return self.entries.pop(0)

    def insert_entry(self, entry: Entry):
        bisect.insort(self.entries, entry)

    def insert_entry_at_the_end(self, entry: Entry):
        """Insert an entry at the end of the entry list.

        This is an optimized version of `insert_entry` when it is known that
        the key to insert is bigger than any other entries.
        """
        self.entries.append(entry)

    def remove_entry(self, key):
        self.entries.pop(self._find_entry_index(key))

    def get_entry(self, key) -> Entry:
        return self.entries[self._find_entry_index(key)]

    def _find_entry_index(self, key) -> int:
        entry = self._entry_class(
            self._tree_conf,
            key=key  # Hack to compare and order
        )
        i = bisect.bisect_left(self.entries, entry)
        if i != len(self.entries) and self.entries[i] == entry:
            return i
        raise ValueError('No entry for key {}'.format(key))

    def split_entries(self) -> list:
        """Split the entries in half.

        Keep the lower part in the node and return the upper one.
        """
        len_entries = len(self.entries)
        rv = self.entries[len_entries // 2:]
        self.entries = self.entries[:len_entries // 2]
        assert len(self.entries) + len(rv) == len_entries
        return rv

    @classmethod
    def from_page_data(cls, tree_conf: TreeConf, data: bytes,
                       page: int = None) -> 'BNode':
        node_type_byte = data[0:NODE_TYPE_BYTES]
        node_type_int = int.from_bytes(node_type_byte, ENDIAN)
        if node_type_int == 1:
            return LonelyRootNode(tree_conf, data, page)
        elif node_type_int == 2:
            return RootNode(tree_conf, data, page)
        elif node_type_int == 3:
            return InternalNode(tree_conf, data, page)
        elif node_type_int == 4:
            return LeafNode(tree_conf, data, page)
        elif node_type_int == 5:
            return OverflowNode(tree_conf, data, page)
        elif node_type_int == 6:
            return FreelistNode(tree_conf, data, page)
        else:
            assert False, 'No Node with type {} exists'.format(node_type_int)

    def __repr__(self):
        return '<{}: page={} entries={}>'.format(
            self.__class__.__name__, self.page, len(self.entries)
        )

    def __eq__(self, other):
        return (
                self.__class__ is other.__class__ and
                self.page == other.page and
                self.entries == other.entries
        )


class RecordNode(BNode):
    __slots__ = ['_entry_class']

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, parent: 'BNode' = None, next_page: int = None):
        self._entry_class = Record
        super().__init__(tree_conf, data, page, parent, next_page)


class LonelyRootNode(RecordNode):
    """A Root node that holds records.

    It is an exception for when there is only a single node in the tree.
    """

    __slots__ = ['_node_type_int', 'min_children', 'max_children']

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, parent: 'BNode' = None):
        self._node_type_int = 1
        self.min_children = 0
        self.max_children = tree_conf.order - 1
        super().__init__(tree_conf, data, page, parent)

    def convert_to_leaf(self):
        leaf = LeafNode(self._tree_conf, page=self.page)
        leaf.entries = self.entries
        return leaf


class LeafNode(RecordNode):
    """Node that holds the actual records within the tree."""

    __slots__ = ['_node_type_int', 'min_children', 'max_children']

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, parent: 'BNode' = None, next_page: int = None):
        self._node_type_int = 4
        self.min_children = math.ceil(tree_conf.order / 2) - 1
        self.max_children = tree_conf.order - 1
        super().__init__(tree_conf, data, page, parent, next_page)


class ReferenceNode(BNode):
    __slots__ = ['_entry_class']

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, parent: 'BNode' = None):
        self._entry_class = Reference
        super().__init__(tree_conf, data, page, parent)

    @property
    def num_children(self) -> int:
        return len(self.entries) + 1 if self.entries else 0

    def insert_entry(self, entry: 'Reference'):
        """Make sure that after of a reference matches before of the next one.

        Probably very inefficient approach.
        """
        super().insert_entry(entry)
        i = self.entries.index(entry)
        if i > 0:
            previous_entry = self.entries[i - 1]
            previous_entry.after = entry.before
        try:
            next_entry = self.entries[i + 1]
        except IndexError:
            pass
        else:
            next_entry.before = entry.after


class RootNode(ReferenceNode):
    """The first node at the top of the tree."""

    __slots__ = ['_node_type_int', 'min_children', 'max_children']

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, parent: 'BNode' = None):
        self._node_type_int = 2
        self.min_children = 2
        self.max_children = tree_conf.order
        super().__init__(tree_conf, data, page, parent)

    def convert_to_internal(self):
        internal = InternalNode(self._tree_conf, page=self.page)
        internal.entries = self.entries
        return internal


class InternalNode(ReferenceNode):
    """Node that only holds references to other Internal nodes or Leaves."""

    __slots__ = ['_node_type_int', 'min_children', 'max_children']

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, parent: 'BNode' = None):
        self._node_type_int = 3
        self.min_children = math.ceil(tree_conf.order / 2)
        self.max_children = tree_conf.order
        super().__init__(tree_conf, data, page, parent)


class OverflowNode(BNode):
    """Node that holds a single Record value too large for its Node."""

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, next_page: int = None):
        self._node_type_int = 5
        self.max_children = 1
        self.min_children = 1
        self._entry_class = OpaqueData
        super().__init__(tree_conf, data, page, next_page=next_page)

    def __repr__(self):
        return '<{}: page={} next_page={}>'.format(
            self.__class__.__name__, self.page, self.next_page
        )


class FreelistNode(BNode):
    """Node that is a marker for a deallocated page."""

    def __init__(self, tree_conf: TreeConf, data: Optional[bytes] = None,
                 page: int = None, next_page: int = None):
        self._node_type_int = 6
        self.max_children = 0
        self.min_children = 0
        super().__init__(tree_conf, data, page, next_page=next_page)

    def __repr__(self):
        return '<{}: page={} next_page={}>'.format(
            self.__class__.__name__, self.page, self.next_page
        )


class FrameType(enum.Enum):
    PAGE = 1
    COMMIT = 2
    ROLLBACK = 3


class WAL:
    __slots__ = ['_fd', '_page_size',
                 '_committed_pages', '_not_committed_pages', 'needs_recovery']

    FRAME_HEADER_LENGTH = (
            FRAME_TYPE_BYTES + PAGE_REFERENCE_BYTES
    )

    def __init__(self, fileobj: io.FileIO, page_size: int):
        self._fd = fileobj
        self._page_size = page_size
        self._committed_pages = dict()
        self._not_committed_pages = dict()

        self._fd.seek(0, io.SEEK_END)
        if self._fd.tell() == 0:
            self._create_header()
            self.needs_recovery = False
        else:
            logging.warning('Found an existing WAL file, '
                           'the B+Tree was not closed properly')
            self.needs_recovery = True
            self._load_wal()

    def checkpoint(self):
        """Transfer the modified data back to the tree and close the WAL."""
        if self._not_committed_pages:
            logging.warning("Closing WAL with uncommitted data, discarding it: %s" % self._fd.name)

        for page, page_start in self._committed_pages.items():
            page_data = read_from_file(
                self._fd,
                page_start,
                page_start + self._page_size
            )
            yield page, page_data

        self._fd.seek(0)
        self._fd.truncate()

    def _create_header(self):
        data = self._page_size.to_bytes(OTHERS_BYTES, ENDIAN)
        self._fd.seek(0)
        write_to_file(self._fd, data)

    def _load_wal(self):
        header_data = read_from_file(self._fd, 0, OTHERS_BYTES)
        assert int.from_bytes(header_data, ENDIAN) == self._page_size

        while True:
            try:
                self._load_next_frame()
            except ReachedEndOfFile:
                break
        if self._not_committed_pages:
            logging.warning('WAL has uncommitted data, discarding it')
            self._not_committed_pages = dict()

    def _load_next_frame(self):
        start = self._fd.tell()
        stop = start + self.FRAME_HEADER_LENGTH
        data = read_from_file(self._fd, start, stop)

        frame_type = int.from_bytes(data[0:FRAME_TYPE_BYTES], ENDIAN)
        page = int.from_bytes(
            data[FRAME_TYPE_BYTES:FRAME_TYPE_BYTES + PAGE_REFERENCE_BYTES],
            ENDIAN
        )

        frame_type = FrameType(frame_type)
        if frame_type is FrameType.PAGE:
            self._fd.seek(stop + self._page_size)

        self._index_frame(frame_type, page, stop)

    def _index_frame(self, frame_type: FrameType, page: int, page_start: int):
        if frame_type is FrameType.PAGE:
            self._not_committed_pages[page] = page_start
        elif frame_type is FrameType.COMMIT:
            self._committed_pages.update(self._not_committed_pages)
            self._not_committed_pages = dict()
        elif frame_type is FrameType.ROLLBACK:
            self._not_committed_pages = dict()
        else:
            assert False

    def _add_frame(self, frame_type: FrameType, page: Optional[int] = None,
                   page_data: Optional[bytes] = None):
        if frame_type is FrameType.PAGE and (not page or not page_data):
            raise ValueError('PAGE frame without page data')
        if page_data and len(page_data) != self._page_size:
            raise ValueError('Page data is different from page size')
        if not page:
            page = 0
        if frame_type is not FrameType.PAGE:
            page_data = b''
        data = (
                frame_type.value.to_bytes(FRAME_TYPE_BYTES, ENDIAN) +
                page.to_bytes(PAGE_REFERENCE_BYTES, ENDIAN) +
                page_data
        )

        self._fd.seek(0, io.SEEK_END)
        write_to_file(self._fd, data)
        self._index_frame(frame_type, page, self._fd.tell() - self._page_size)

    def get_page(self, page: int) -> Optional[bytes]:
        page_start = None
        for store in (self._not_committed_pages, self._committed_pages):
            page_start = store.get(page)
            if page_start:
                break

        if not page_start:
            return None

        return read_from_file(self._fd, page_start,
                              page_start + self._page_size)

    def set_page(self, page: int, page_data: Union[bytes, bytearray]):
        self._add_frame(FrameType.PAGE, page, page_data)

    def commit(self):
        # Commit is a no-op when there is no uncommitted pages
        if self._not_committed_pages:
            self._add_frame(FrameType.COMMIT)

    def rollback(self):
        # Rollback is a no-op when there is no uncommitted pages
        if self._not_committed_pages:
            self._add_frame(FrameType.ROLLBACK)

    def __repr__(self):
        return '<WAL: {}>'.format(self.filename)


class FakeCache:
    """A cache that doesn't cache anything.

    Because cachetools does not work with maxsize=0.
    """

    def get(self, k):
        pass

    def __setitem__(self, key, value):
        pass

    def clear(self):
        pass


class FileMemory:
    __slots__ = ['_tree_conf', '_lock', '_cache', '_fd', '_journal',
                 '_wal', 'last_page', '_freelist_start_page',
                 '_root_node_page']

    def __init__(self, file_db: io.FileIO, file_journal: io.FileIO, tree_conf: TreeConf,
                 cache_size: int = 512):
        self._tree_conf = tree_conf
        self._lock = rwlock.RWLock()

        if cache_size == 0:
            self._cache = FakeCache()
        else:
            self._cache = cachetools.LRUCache(maxsize=cache_size)

        self._fd = file_db
        self._journal = file_journal

        self._wal = WAL(self._journal, tree_conf.page_size)
        if self._wal.needs_recovery:
            self.perform_checkpoint(reopen_wal=True)

        # Get the next available page
        self._fd.seek(0, io.SEEK_END)
        last_byte = self._fd.tell()

        self.last_page = int(last_byte / self._tree_conf.page_size)
        self._freelist_start_page = 0

        # Todo: Remove this, it should only be in Tree
        self._root_node_page = 0

    def get_node(self, page: int):
        """Get a node from storage.

        The cache is not there to prevent hitting the disk, the OS is already
        very good at it. It is there to avoid paying the price of deserializing
        the data to create the Node object and its entry. This is a very
        expensive operation in Python.

        Since we have at most a single writer we can write to cache on
        `set_node` if we invalidate the cache when a transaction is rolled
        back.
        """
        node = self._cache.get(page)
        if node is not None:
            return node

        data = self._wal.get_page(page)
        if not data:
            data = self._read_page(page)

        node = BNode.from_page_data(self._tree_conf, data=data, page=page)
        self._cache[node.page] = node
        return node

    def set_node(self, node: BNode):
        self._wal.set_page(node.page, node.dump())
        self._cache[node.page] = node

    def del_node(self, node: BNode):
        self._insert_in_freelist(node.page)

    def del_page(self, page: int):
        self._insert_in_freelist(page)

    @property
    def read_transaction(self):

        class ReadTransaction:

            def __enter__(self2):
                self._lock.reader_lock.acquire()

            def __exit__(self2, exc_type, exc_val, exc_tb):
                self._lock.reader_lock.release()

        return ReadTransaction()

    @property
    def write_transaction(self):

        class WriteTransaction:

            def __enter__(self2):
                self._lock.writer_lock.acquire()

            def __exit__(self2, exc_type, exc_val, exc_tb):
                if exc_type:
                    # When an error happens in the middle of a write
                    # transaction we must roll it back and clear the cache
                    # because the writer may have partially modified the Nodes
                    self._wal.rollback()
                    self._cache.clear()
                else:
                    self._wal.commit()
                self._lock.writer_lock.release()

        return WriteTransaction()

    @property
    def next_available_page(self) -> int:
        last_freelist_page = self._pop_from_freelist()
        if last_freelist_page is not None:
            return last_freelist_page

        self.last_page += 1
        return self.last_page

    def _traverse_free_list(self) -> Tuple[Optional[FreelistNode],
                                           Optional[FreelistNode]]:
        if self._freelist_start_page == 0:
            return None, None

        second_to_last_node = None
        last_node = self.get_node(self._freelist_start_page)

        while last_node.next_page is not None:
            second_to_last_node = last_node
            last_node = self.get_node(second_to_last_node.next_page)

        return second_to_last_node, last_node

    def _insert_in_freelist(self, page: int):
        """Insert a page at the end of the freelist."""
        _, last_node = self._traverse_free_list()

        self.set_node(FreelistNode(self._tree_conf, page=page, next_page=None))

        if last_node is None:
            # Write in metadata that the freelist got a new starting point
            self._freelist_start_page = page
            self.set_metadata(None, None)
        else:
            last_node.next_page = page
            self.set_node(last_node)

    def _pop_from_freelist(self) -> Optional[int]:
        """Remove the last page from the freelist and return its page."""
        second_to_last_node, last_node = self._traverse_free_list()

        if last_node is None:
            # Freelist is completely empty, nothing to pop
            return None

        if second_to_last_node is None:
            # Write in metadata that the freelist is empty
            self._freelist_start_page = 0
            self.set_metadata(None, None)
        else:
            second_to_last_node.next_page = None
            self.set_node(second_to_last_node)

        return last_node.page

    # Todo: make metadata as a normal Node
    def get_metadata(self) -> tuple:
        try:
            data = self._read_page(0)
        except ReachedEndOfFile:
            raise ValueError('Metadata not set yet')
        end_root_node_page = PAGE_REFERENCE_BYTES
        root_node_page = int.from_bytes(
            data[0:end_root_node_page], ENDIAN
        )
        end_page_size = end_root_node_page + OTHERS_BYTES
        page_size = int.from_bytes(
            data[end_root_node_page:end_page_size], ENDIAN
        )
        end_order = end_page_size + OTHERS_BYTES
        order = int.from_bytes(
            data[end_page_size:end_order], ENDIAN
        )
        end_key_size = end_order + OTHERS_BYTES
        key_size = int.from_bytes(
            data[end_order:end_key_size], ENDIAN
        )
        end_value_size = end_key_size + OTHERS_BYTES
        value_size = int.from_bytes(
            data[end_key_size:end_value_size], ENDIAN
        )
        end_item_size = end_value_size + OTHERS_BYTES
        item_size = int.from_bytes(
            data[end_value_size:end_item_size], ENDIAN
        )
        end_freelist_start_page = end_item_size + PAGE_REFERENCE_BYTES
        self._freelist_start_page = int.from_bytes(
            data[end_item_size:end_freelist_start_page], ENDIAN
        )
        self._tree_conf = TreeConf(
            page_size, order, key_size, value_size, item_size, self._tree_conf.serializer
        )
        self._root_node_page = root_node_page
        return root_node_page, self._tree_conf

    def set_metadata(self, root_node_page: Optional[int],
                     tree_conf: Optional[TreeConf]):

        if root_node_page is None:
            root_node_page = self._root_node_page

        if tree_conf is None:
            tree_conf = self._tree_conf

        length = 2 * PAGE_REFERENCE_BYTES + 5 * OTHERS_BYTES
        data = (
                root_node_page.to_bytes(PAGE_REFERENCE_BYTES, ENDIAN) +
                tree_conf.page_size.to_bytes(OTHERS_BYTES, ENDIAN) +
                tree_conf.order.to_bytes(OTHERS_BYTES, ENDIAN) +
                tree_conf.key_size.to_bytes(OTHERS_BYTES, ENDIAN) +
                tree_conf.value_size.to_bytes(OTHERS_BYTES, ENDIAN) +
                tree_conf.item_size.to_bytes(OTHERS_BYTES, ENDIAN) +
                self._freelist_start_page.to_bytes(PAGE_REFERENCE_BYTES, ENDIAN) +
                bytes(tree_conf.page_size - length)
        )
        self._write_page_in_tree(0, data)

        self._tree_conf = tree_conf
        self._root_node_page = root_node_page

    def close(self):
        self.perform_checkpoint()
        self._fd.flush()
        self._fd.close()
        self._journal.close()

    def perform_checkpoint(self, reopen_wal=False):
        for page, page_data in self._wal.checkpoint():
            self._write_page_in_tree(page, page_data)
        self._fd.flush()
        if reopen_wal:
            self._wal = WAL(self._journal, self._tree_conf.page_size)

    def _read_page(self, page: int) -> bytes:
        start = page * self._tree_conf.page_size
        stop = start + self._tree_conf.page_size
        assert stop - start == self._tree_conf.page_size
        return read_from_file(self._fd, start, stop)

    def _write_page_in_tree(self, page: int, data: Union[bytes, bytearray]):
        """Write a page of data in the tree file itself.

        To be used during checkpoints and other non-standard uses.
        """
        assert len(data) == self._tree_conf.page_size
        self._fd.seek(page * self._tree_conf.page_size)
        write_to_file(self._fd, data)

    def __repr__(self):
        return '<FileMemory: {}>'.format(self.__filename)


class BaseTree(ABC):
    """Base of a BPlusTree."""

    __slots__ = ['_tree_conf', '_mem', '_root_node_page',
                 '_is_open', 'LonelyRootNode', 'RootNode', 'InternalNode',
                 'LeafNode', 'OverflowNode', 'Record', 'Reference']

    def __init__(self, file_db: io.FileIO, file_journal: io.FileIO, page_size: int = 4096,
                 key_size: int = 8, value_size: int = 32, cache_size: int = 64,
                 serializer: Optional[Serializer] = None):
        self._tree_conf = self._conf(page_size, key_size, value_size, serializer)

        if self._tree_conf.order < 4:
            raise RuntimeError("The order must be at least 4, try increase page size.")

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
        self.LonelyRootNode = functools.partial(LonelyRootNode, self._tree_conf)
        self.RootNode = functools.partial(RootNode, self._tree_conf)
        self.InternalNode = functools.partial(InternalNode, self._tree_conf)
        self.LeafNode = functools.partial(LeafNode, self._tree_conf)
        self.OverflowNode = functools.partial(OverflowNode, self._tree_conf)
        self.Record = functools.partial(Record, self._tree_conf)
        self.Reference = functools.partial(Reference, self._tree_conf)

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

    def _search_in_tree(self, key, node) -> 'BNode':
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

    def _split_leaf(self, old_node: 'BNode'):
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

    def _split_parent(self, old_node: BNode):
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

        assert len(old_node.entries) > 0 and len(new_node.entries) > 0

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
            page_size, page_size // (value_size + 24), key_size, value_size, value_size,
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
                raise ValueError("Key doesn't exist")
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
                return None
            else:
                rv = self._get_value_from_record(record)
                assert isinstance(rv, bytes)
                return rv

    def delete(self, key, default=None):
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
                first_overflow_page = self._create_overflow(value) if value else None

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
                length = record.value if type(record.value) is int else int.from_bytes(record.value, ENDIAN)
                if length:
                    record.overflow_page, record.value = self._update_overflow(
                        record.overflow_page,
                        length,
                        insertions,
                        deletions
                    )
                else:
                    length = len(insertions)
                    record.value = length.to_bytes(OTHERS_BYTES, byteorder=ENDIAN)
                    record.overflow_page = self._create_overflow(tuple(insertions))

                self._mem.set_node(node)

    def batch_insert(self, iterable: Iterable):
        raise NotImplementedError()

    def get(self, key, default=list()) -> list:
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                return None
            else:
                length = int.from_bytes(record.value, ENDIAN)
                if length:
                    rv = self._get_value_from_record(record)
                    assert isinstance(rv, list)
                    return rv
                else:
                    return list()

    def delete(self, key, default=None):
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                pass
            else:
                length = int.from_bytes(record.value, ENDIAN)
                if length:
                    self._delete_overflow(record.overflow_page)
                node.remove_entry(key)
                self._mem.set_node(node)

    def clear(self, key):
        with self._mem.read_transaction:
            node = self._search_in_tree(key, self._root_node)
            try:
                record = node.get_entry(key)
            except ValueError:
                pass
            else:
                length = int.from_bytes(record.value, ENDIAN)
                if length:
                    self._delete_overflow(record.overflow_page)
                    record.overflow_page = None
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
                if isinstance(item, bytes):
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
            if isinstance(item, bytes):
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
            if isinstance(item, bytes):
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