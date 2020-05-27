# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Data streams."""
import fcntl
import hashlib
import os
import struct
import uuid
from abc import abstractmethod, ABC
from os import SEEK_CUR, SEEK_SET, SEEK_END
from typing import Union

import libnacl.secret
from archive7.base import BaseFileObject
from bplustree.serializer import UUIDSerializer
from bplustree.tree import SingleItemTree

BLOCK_SIZE = 4096
DATA_SIZE = 4008
MAX_UINT32 = 2 ** 32


class StreamBlock:
    """A block of data in a stream.

    The amount of raw data is set to 4020 bytes, except 16 bytes for metadata and 20 bytes of digest.
    This sums up to 4056 bytes, after encryption and its digest we end up with 4096 bytes or 4 Kb.

        self.previous. 4 bytes, signed integer linking to previous block.
        self.next. 4 bytes, signed integer linking to next block.
        self.index. 4 bytes, unsigned integer block in stream index.
        self.stream. 16 bytes, unsigned integer setting stream id.
        self.digest. 20 bytes, sha1 digest of the data field.
        self.data. 4004 bytes
    """

    __slots__ = ["__position", "previous", "next", "index", "stream", "digest", "data"]

    FORMAT = "!iiI16s20s4008s"
    SIZE = struct.calcsize("!iiI16s20s4008s")

    def __init__(self, position: int, previous: int = -1, next: int = -1, index: int = 0,
                 stream: uuid.UUID = uuid.UUID(int=0),
                 block: bytes = None):
        self.__position = position

        self.previous = previous
        self.next = next
        self.index = index
        self.stream = stream
        self.digest = None
        self.data = bytearray(DATA_SIZE)

        if block:
            self.load_meta(block)

    @property
    def position(self) -> int:
        """Expose stream block position in file."""
        return self.__position

    def load_meta(self, block: bytes) -> bool:
        """Unpack a block of bytes into its components and populate the fields

        Args:
            block (bytes):
                Bytes to be read into a data block.

        Returns (bool):
            True if the loaded data is not corrupt else False

        """
        valid = True
        data = None
        stream = None
        (
            self.previous, self.next, self.index, stream, self.digest, data
        ) = struct.unpack(StreamBlock.FORMAT, block)
        if hashlib.sha1(self.data).digest() != self.digest:
            valid = False

        self.stream = uuid.UUID(bytes=stream)
        self.data[:] = data[:]
        return valid

    def __bytes__(self) -> bytes:
        return struct.pack(
            StreamBlock.FORMAT,
            self.previous,
            self.next,
            self.index,
            self.stream.bytes,
            hashlib.sha1(self.data).digest(),
            self.data
        )


class BaseStream:  # (Iterable, Reversible):
    """Descriptor for an open data stream to be read and written too.

    Data streams should be wrapped in a file descriptor.

        self.__identity. unsigned integer, the id number of the stream in the registry.
        self.__begin. signed integer, position of the first block in the stream.
        self.__end. signed integer, position of the last block in the stream.
        self.__count. unsigned integer, number of blocks used.
        self.__length. unsigned long long, number of bytes in the data stream.
        self.__compression, unsigned short, compression algorithm of choice.
    """

    __slots__ = [
        "_manager", "_block", "__changed", "_identity", "_begin",
        "_end", "_count", "_length", "_compression"
    ]

    COMP_NONE = 0

    FORMAT = "!16siiIQH"
    SIZE = struct.calcsize("!16siiIQH")

    def __init__(
        self, manager: "StreamManager", block: StreamBlock, identity: uuid.UUID, begin: int = -1,
        end: int = -1, count: int = 0, length: int = 0, compression: int = 0
    ):
        self._manager = manager
        self._block = block
        self.__changed = False
        block.stream = identity

        self._identity = identity
        self._begin = begin
        self._end = end
        self._count = count
        self._length = length
        self._compression = compression

    @property
    def identity(self):
        """Expose the streams identity number."""
        return self._identity

    @property
    def manager(self):
        """Expose stream manager."""
        return self._manager

    @property
    def data(self):
        """Expose the current block's data section."""
        return self._block.data

    def load_meta(self, stream: Union[bytearray, bytes]) -> bool:
        """Unpack metadata and populate the fields.

        Args:
            stream (Union[bytearray, bytes]):
                Bytes to be read into metadata.

        Returns (bool):
            True if the loaded data is not corrupt else False

        """
        (
            self._identity, self._begin, self._end, self._count, self._length, self._compression
        ) = DataStream.meta_unpack(stream)
        return True

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        """

        Args:
            data (Union[bytes, bytearray]):
                Data to be unpacked

        Returns (tuple):
            Unpacked tuple

        """
        metadata = struct.unpack(DataStream.FORMAT, data)
        identity = uuid.UUID(bytes=metadata[0])
        return (identity,) + metadata[1:]

    def __bytes__(self):
        return struct.pack(
            DataStream.FORMAT,
            self._identity.bytes,
            self._begin,
            self._end,
            self._count,
            self._length,
            self._compression
        )

    def __iter__(self):
        forward = True
        if self._block.position != self._begin:
            self._manager.save_block(self._block)
            self._block = self._manager.load_block(self._begin)

        while forward:
            forward = self.next()
            yield bytes(self._block.data)

    def __reversed__(self):
        backward = True
        if self._block.position != self._end:
            self._manager.save_block(self._block)
            self._block = self._manager.load_block(self._end)

        while backward:
            backward = self.previous()
            yield bytes(self._block.data)

    def length(self, change: int = 0) -> int:
        """Tell and update the length of the stream in used bytes.

        Args:
            change (int):
                A relative number of bytes added or subtracted.

        Returns (int):
            Current or new length of stream.

        """
        self._length += change
        return self._length

    def changed(self):
        """Indicate that the current block has been written to."""
        self.__changed = True

    def save(self, enforce: bool = False):
        """Save current block if changed or enforced.

        Args:
            enforce (bool):
                Enforce writing the block to disk.

        """
        if self.__changed or enforce:
            self._manager.save_block(self._block.position, self._block)
            self.__changed = False

    def next(self) -> bool:
        """Load next data block in the stream.

        Returns (bool):
            True if next block loads, if it is last block False.

        """
        return self.__step(self._block.next)

    def previous(self) -> bool:
        """Load previous data block in the stream.

        Returns (bool):
            True if previous block loads, if it is last block False.

        """
        return self.__step(self._block.previous)

    def __step(self, to: int) -> bool:
        if to == -1:
            return False
        else:
            self.save()
            block = self._manager.load_block(to)
            self._block = block
            return True

    def extend(self) -> bool:
        """Create a new block at the end of stream.

        Returns (bool):
            True if successfully created a new block or False if not at end of stream.

        """
        if self._block.next != -1:
            return False
        else:
            block = self._manager.new_block()
            block.index = self._count  # The current count is the same as the new index
            block.stream = self._identity
            block.previous = self._block.position
            block.next = -1
            self._block.next = block.position
            self._end = block.position
            self._count += 1  # Update the count after indexing
            self.save()
            self._block = block
            return True

    def truncate(self, length: int) -> int:
        """Truncate the stream to a certian length and recycle blocks.

        Args:
            length (int):
                New length of stream.

        Returns (int):
            New length of stream.

        """
        index = length // DATA_SIZE
        offset = length % DATA_SIZE
        remnant = DATA_SIZE - offset

        self.save()
        if self.wind(index) != index:
            raise OSError("Couldn't truncate, winding problem.")

        self._block.data[offset:] = b"\x00" * remnant
        self.save(True)

        self._end = self._block.position
        self._count = self._block.index + 1
        self._length = length

        if self._block.next != -1:
            next = self._block.next

            self._block.next = -1
            self.save(True)

            block = self._manager.load_block(next)
            # block.previous = -1
            # self._manager.save_block(block.position, block)
            self._manager.recycle(block)

        return length

    def wind(self, index: int) -> int:
        """Wind forward or backward to block index.

        Args:
            index (int):
                Block index to wind to.

        Returns (int):
            New block index.

        """

        pos = -1
        current = self._block

        if self._block.index < index:  # Go forward
            while self.next():
                if self._block.index == index:
                    pos = index
                    break
        elif self._block.index > index:  # Go backward
            while self.previous():
                if self._block.index == index:
                    pos = index
                    break

        if pos == -1:
            self._block = current
            pos = current.index

        return pos

    @abstractmethod
    def close(self):
        """Save and close stream at manager."""
        pass


class InternalStream(BaseStream):
    """Stream for internal use in StreamManager."""

    def close(self):
        """Save block."""
        self.save()


class TrashStream(InternalStream):

    def push_block(self, block: StreamBlock):
        """Push a block at end of stream.

        Args:
            block (StreamBlock):
                Block to push.

        """
        if self._end == self._block.position:
            last_blk = self._block
        else:
            last_blk = self._manager.load_block(self._end)

        last_blk.next = block.position
        block.previous = last_blk.position
        block.next = -1
        block.stream = self._identity
        block.index = self._count
        self._end = block.position
        self._count += 1

        self._manager.save_block(last_blk)
        self._manager.save_block(block)
        self._manager.save_meta()

    def pop_block(self) -> StreamBlock:
        """Pop block off the end of stream.

        Returns (StreamBlock):
            Popped block.

        """
        if not self._count > 1:
            return None

        if self._end == self._block.position:
            last_blk = self._block
        else:
            last_blk = self._manager.load_block(self._end)

        if last_blk.previous == self._block.position:
            prev_blk = self._block
        else:
            prev_blk = self._manager.load_block(last_blk.previous)

        last_blk.previous = -1
        prev_blk.next = -1
        self._end = prev_blk.position
        self._count -= 1

        self._manager.save_block(prev_blk)
        self._manager.save_meta()

        return last_blk


class DataStream(BaseStream):
    """Stream for general use."""

    def close(self):
        """Save block and close stream at manager."""
        self.save()
        self._manager.close_stream(self)


class VirtualFileObject(BaseFileObject):
    """Stream for the registry index database."""

    __slots__ = ["_stream", "_position", "__offset", "__end"]

    def __init__(self, stream: DataStream, filename: str, mode: str = "r"):
        self._stream = stream
        self._position = 0
        self.__offset = 0
        self.__end = stream.length()
        BaseFileObject.__init__(self, filename, mode)

    def _close(self):
        self._stream.close()

    def _flush(self):
        self._stream.save(True)

    def _readinto(self, b):
        m = memoryview(b).cast("B")
        size = min(len(m), self.__end - self._position)

        data = bytearray()
        cursor = 0
        # FIXME: Save data here?

        while size > cursor:
            num_copy = min(DATA_SIZE - self.__offset, size - cursor)

            data += self._stream.data[self.__offset:self.__offset + num_copy]
            cursor += num_copy
            self._position += num_copy
            self.__offset += num_copy

            if self.__offset == DATA_SIZE:
                self._stream.next()
                self.__offset = 0

        n = len(data)
        m[:n] = data
        return n

    def _seek(self, offset, whence):
        if whence == SEEK_SET:
            cursor = min(max(offset, 0), self.__end)
        elif whence == SEEK_CUR:
            if offset < 0:
                cursor = max(self._position + offset, 0)
            else:
                cursor = min(self._position + offset, self.__end)
        elif whence == SEEK_END:
            cursor = max(min(self.__end + offset, self.__end), 0)
        else:
            raise OSError("Invalid seek, %s" % whence)

        block = cursor // DATA_SIZE
        if self._stream.wind(block) != block:
            return self._position
            # raise OSError("Couldn't seek to position, problem with underlying stream.")
        else:
            self.__offset = cursor - (block * DATA_SIZE)
            self._position = cursor
            return self._position

    def _truncate(self, size):
        if size:
            self._stream.truncate(size)
            self.__end = size
        else:
            self._stream.truncate(self._position)
            self.__end = self._position
        return self.__end

    def _write(self, b):
        write_len = len(b)
        if not write_len:
            return 0

        cursor = 0

        while write_len > cursor:
            self._stream.changed()
            num_copy = min(DATA_SIZE - self.__offset, write_len - cursor)

            self._stream.data[self.__offset:self.__offset + num_copy] = b[cursor:cursor + num_copy]

            cursor += num_copy
            self._position += num_copy
            self.__offset += num_copy
            if self._position > self.__end:  # Updating stream length
                self._stream.length(self._position - self.__end)
                self.__end = self._position

            if self.__offset >= DATA_SIZE:  # Load next or new block
                if not self._stream.next():
                    if not self._stream.extend():
                        raise OSError("Out of space.")
                self.__offset = 0

        return cursor if cursor else None


class Registry(ABC):
    """B+Tree registry and wal wrapper"""

    __slots__ = ["__tree", "__cnt", "__manager"]

    def __init__(self, manager: "DynamicMultiStreamManager"):
        self.__cnt = 0
        self._manager = manager
        self._tree = self._init_tree()

    @property
    def tree(self):
        return self._tree

    def close(self):
        self._tree.checkpoint()
        self._tree.close()

    @abstractmethod
    def _init_tree(self, main: DataStream, wal: DataStream, key_size: int, value_size: int):
        pass

    def _checkpoint(self, enforce: bool = False):
        self.__cnt += 1
        if self.__cnt >= 10 or enforce:
            self._tree.checkpoint()
            self.__cnt = 0


class StreamRegistry(Registry):
    """Registry to keep track of all streams and the trash."""

    __slots__ = []

    def _init_tree(self):
        return SingleItemTree(
            VirtualFileObject(
                self._manager.special_stream(DynamicMultiStreamManager.STREAM_INDEX),
                "main", "wb+"
            ),
            VirtualFileObject(
                self._manager.special_stream(DynamicMultiStreamManager.STREAM_INDEX_WAL),
                "wal", "wb+"
            ),
            page_size=DATA_SIZE // 4,
            key_size=16,
            value_size=DataStream.SIZE,
            serializer=UUIDSerializer()
        )

    def register(self, stream: DataStream) -> int:
        """Register a data stream.

        Args:
            stream (DataStream):
                Stream to be registered.

        Returns (int):
            Stream identity number.

        """
        self._tree.insert(stream.identity, bytes(stream))
        self._checkpoint()
        return stream.identity

    def unregister(self, identity: int) -> bytes:
        """Unregister a data stream.

        Args:
            identity (int):
                Stream identity number.

        Returns (bytes):
            Stream metadata.

        """

        result = self._tree.delete(identity)
        self._checkpoint()
        return result

    def update(self, stream: DataStream) -> bool:
        """Update stream metadata.

        Args:
            stream (DataStream):
                Stream to update metadata from.

        Returns (bool):
            Success of update.

        """
        try:
            self._tree.update(stream.identity, bytes(stream))
            self._checkpoint()
            return True
        except ValueError:
            return False

    def search(self, identity: int) -> bytes:
        """Search for a stream by identity number.

        Args:
            identity (int):
                Identity number.

        Returns (bytes):
            Stream metadata.

        """
        return self._tree.get(identity)




class StreamManager(ABC):
    """Stream manager handles streams with their blocks and provides transparent encryption.

    Transparent encryption is built in including standards for carrying out different kind of
    operations on the streams and blocks.
    """

    __slots__ = ["__created", "__filename", "__closed", "__file", "__secret", "__box", "__count", "__meta", "__blocks",
                 "__internal", "_streams"]

    SPECIAL_BLOCK_COUNT = 0
    SPECIAL_STREAM_COUNT = 0

    BLOCK_META = 0

    def __init__(self, filename: str, secret: bytes):
        self.__created = False
        self.__filename = filename
        self.__closed = False
        self.__file = None
        self.__secret = secret
        self.__box = libnacl.secret.SecretBox(secret)
        self.__count = 0
        self.__meta = bytearray(b"\x00" * (DATA_SIZE - (self.SPECIAL_STREAM_COUNT * DataStream.SIZE)))
        self.__blocks = [None for _ in range(max(self.SPECIAL_BLOCK_COUNT, 1))]
        self.__internal = [None for _ in range(self.SPECIAL_STREAM_COUNT)]
        self._streams = dict()

        if os.path.isfile(filename):
            # Open and use file
            self.__file = open(self.__filename, "rb+", BLOCK_SIZE)
            fcntl.lockf(self.__file, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.__file.seek(0, os.SEEK_END)
            length = self.__file.tell()
            if length % BLOCK_SIZE:
                raise OSError("Archive length uneven to block size.")
            self.__count = length // BLOCK_SIZE

            for i in range(max(self.SPECIAL_BLOCK_COUNT, 1)):
                self.__blocks[i] = self.load_block(i)

            streams_data = self.__load_meta()
            for i in range(self.SPECIAL_STREAM_COUNT):
                metadata = DataStream.meta_unpack(streams_data[i])
                stream = InternalStream(self, self.load_block(metadata[1]), *metadata)
                if stream.identity.int != i:
                    raise RuntimeError("Corrupt internal stream identifier, %s." % stream.identity)
                self.__internal[i] = stream
                self._streams[stream.identity] = stream

            self._open()
        else:
            # Setup file before using
            self.__file = open(self.__filename, "wb+", BLOCK_SIZE)
            fcntl.lockf(self.__file, fcntl.LOCK_EX | fcntl.LOCK_NB)

            for i in range(max(self.SPECIAL_BLOCK_COUNT, 1)):
                self.__blocks[i] = self.new_block()

            for i in range(self.SPECIAL_STREAM_COUNT):
                identity = uuid.UUID(int=i)
                block = self.new_block()
                block.index = 0
                block.stream = identity
                stream = InternalStream(self, block, identity, begin=block.position, end=block.position, count=1)
                self.__internal[i] = stream
                self._streams[identity] = stream

            self.__save_meta()
            self._setup()
            self.__created = True

    @property
    def closed(self):
        return self.__closed

    @property
    def created(self):
        return self.__created

    def close(self):
        if not self.closed:
            self._close()

            for i in range(self.SPECIAL_STREAM_COUNT):
                self.__internal[i].close()
                del self._streams[self.__internal[i].identity]
            self.__save_meta()

            self.__file.flush()
            os.fsync(self.__file.fileno())
            fcntl.lockf(self.__file, fcntl.LOCK_UN)
            self.__file.close()
            self.__closed = True

    def __load_meta(self):
        block = self.special_block(self.BLOCK_META)
        stream_size = DataStream.SIZE * self.SPECIAL_STREAM_COUNT
        self.__meta = block.data[0:DATA_SIZE - stream_size]
        data = block.data[DATA_SIZE - stream_size:DATA_SIZE]
        stream_data = list()

        for i in range(self.SPECIAL_STREAM_COUNT):
            chunk = data[i * DataStream.SIZE:i * DataStream.SIZE + DataStream.SIZE]
            stream_data.append(chunk)

        return stream_data

    def __save_meta(self):
        data = b""
        block = self.special_block(self.BLOCK_META)
        stream_size = DataStream.SIZE * self.SPECIAL_STREAM_COUNT

        for i in range(self.SPECIAL_STREAM_COUNT):
            data += bytes(self.special_stream(i))

        block.data[DATA_SIZE - stream_size:DATA_SIZE] = data[0:stream_size]
        block.data[0:DATA_SIZE - stream_size] = self.__meta[0:DATA_SIZE - stream_size]
        self.save_block(block.index, block)

    def save_meta(self):
        """Save meta information."""
        self.__save_meta()

    @property
    def meta(self) -> bytes:
        return self.__meta

    @meta.setter
    def meta(self, meta: bytes):
        self.__meta = meta

    def special_block(self, position: int):
        """Receive one of the 8 reserved special blocks."""
        if 0 <= position <= 7:
            return self.__blocks[position]
        else:
            raise IndexError("Index must be between 0 and 7, was %s." % position)

    def new_block(self) -> StreamBlock:
        """Create new block at the end of file, write empty block to file.

        Returns (StreamBlock):
            The newly created block.

        """
        block = self.reuse()
        if block:
            block.data[0:DATA_SIZE] = b"\x00" * DATA_SIZE
        else:
            offset = self.__file.seek(0, os.SEEK_END)
            index = offset // BLOCK_SIZE
            block = StreamBlock(position=index)
            self.__count += 1
        length = self.__file.write(self.__box.encrypt(bytes(block)))
        if length != BLOCK_SIZE:
            raise OSError("Failed writing full block, wrote %s bytes instead of %s." % (length, BLOCK_SIZE))
        return block

    def load_block(self, index: int) -> StreamBlock:
        """Load a block from index and decrypt.

        Args:
            index (int):
                Block index.

        Returns (StreamBlock):
            Loaded block a stream block.

        """
        if not index < self.__count:
            raise IndexError("Index out of bounds, %s of %s." % (index, self.__count))
        position = index * BLOCK_SIZE
        offset = self.__file.seek(position)
        if position != offset:
            raise OSError("Failed to seek for position %s, ended at %s." % (position, offset))
        return StreamBlock(position=index, block=self.__box.decrypt(self.__file.read(BLOCK_SIZE)))

    def save_block(self, index: int, block: StreamBlock):
        """Save a block and encrypt it.

        Args:
            index (int):
                Index for offset where to write block
            block (StreamBlock):
                Block to save to file.

        """
        if not index < self.__count:
            raise IndexError("Index out of bounds, %s of %s." % (index, self.__count))
        if index != block.position:
            raise IndexError("Index %s and position %s are not the same." % (index, block.position))
        position = index * BLOCK_SIZE
        offset = self.__file.seek(position)
        if not position == offset:
            raise OSError("Failed to seek for position %s, ended at %s." % (position, offset))
        length = self.__file.write(self.__box.encrypt(bytes(block)))
        self.__file.flush()
        os.fsync(self.__file.fileno())
        if length != BLOCK_SIZE:
            raise OSError("Failed writing full block, wrote %s bytes instead of %s." % (length, BLOCK_SIZE))

    def special_stream(self, position: int):
        """Receive one of the 3 reserved special streams."""
        if 0 <= position < self.SPECIAL_STREAM_COUNT:
            return self.__internal[position]
        else:
            raise IndexError("Index must be between 0 and %s, was %s." % (self.SPECIAL_STREAM_COUNT, position))

    def _setup(self):
        pass

    def _open(self):
        pass

    def _close(self):
        pass

    @abstractmethod
    def recycle(self, chain: StreamBlock) -> bool:
        pass

    @abstractmethod
    def reuse(self) -> StreamBlock:
        pass


class SingleStreamManager(StreamManager):
    SPECIAL_BLOCK_COUNT = 1
    SPECIAL_STREAM_COUNT = 1

    STREAM_DATA = 0

    def recycle(self, chain: StreamBlock) -> bool:
        """Truncate stream at block position."""
        self.__file.seek(chain.position * BLOCK_SIZE)
        self.__file.truncate()
        self.__count = self.__file.tell() // BLOCK_SIZE

    def reuse(self) -> StreamBlock:
        """Single stream don't need reuse."""
        return None


class FixedMultiStreamManager(StreamManager):
    """Multi stream manager, that manages a fixed set of streams."""
    SPECIAL_BLOCK_COUNT = 1
    SPECIAL_STREAM_COUNT = 1

    STREAM_TRASH = 0

    def recycle(self, chain: StreamBlock):
        """Recycle a truncated chain of blocks from a stream.

        Args:
            chain (StreamBlock):
                Block and chain that will be recycled

        """
        trash = self.special_stream(self.STREAM_TRASH)

        while chain.next != -1:
            block = chain
            chain = self.load_block(chain.next)
            trash.push_block(block)

        trash.push_block(chain)

    def reuse(self) -> StreamBlock:
        """Get a recycled block if any available.

        Returns (StreamBlock):
            Block to be reused or None

        """
        trash = self.special_stream(self.STREAM_TRASH)
        if not trash:
            return None
        return trash.pop_block()


class DynamicMultiStreamManager(FixedMultiStreamManager):
    """Stream manager handles all the streams and blocks that are underlying of a virtual file system.

    The underlying system is built up of 4Kb blocks that can be chained like linked lists, those are data streams.
    There can be and are several data streams, they can be used for files and can expand by adding more blocks,
    thanks to this streams can grow in size.

    There are reserved blocks and streams. In total the first eight blocks are reserved, so are the first eight
    streams.
    """

    __slots__ = ["__registry"]

    SPECIAL_BLOCK_COUNT = 1
    SPECIAL_STREAM_COUNT = 3

    STREAM_INDEX = 1
    STREAM_INDEX_WAL = 2

    def __init__(self, filename: str, secret: bytes):
        StreamManager.__init__(self, filename, secret)
        self.__registry = StreamRegistry(self)

    def _close(self):
        self.__registry.close()

    def new_stream(self) -> DataStream:
        """Create a new data stream.

        Returns (DataStream):
            The new data stream created.

        """
        identity = uuid.uuid4()
        block = self.new_block()
        block.index = 0
        block.stream = identity
        stream = DataStream(self, block, identity, begin=block.position, end=block.position, count=1)
        self.__registry.register(stream)
        self._streams[stream.identity] = stream
        return stream

    def open_stream(self, identity: uuid.UUID) -> DataStream:
        """Open an existing data stream.

        Args:
            identity (uuid.UUID):
                Data stream number.

        Returns (DataStream):
            The opened data stream object.

        """
        if identity in self._streams.keys():
            raise OSError("Already opened")
        data = self.__registry.search(identity)
        if not data:
            raise OSError("Identity doesn't exist %s" % identity)
        metadata = DataStream.meta_unpack(data)
        if metadata[0] != identity:
            raise OSError("Identity doesn't match stream %s" % identity)
        stream = DataStream(self, self.load_block(metadata[1]), *metadata)
        self._streams[identity] = stream
        return stream

    def close_stream(self, stream: DataStream) -> bool:
        """Close an open data stream.

        Args:
            stream (DataStream):
                Data stream object being saved.

        """
        if stream.identity not in self._streams:
            raise OSError("Stream not known to be open.")
        stream.save()
        self.__registry.update(stream)
        del self._streams[stream.identity]
        del stream

    def del_stream(self, identity: uuid.UUID) -> bool:
        """Delete data stream from file.

        Args:
            identity (uuid.UUID):
                Data stream number to be erased.

        Returns (bool):
            Success of deleting data stream.

        """
        metadata = DataStream.meta_unpack(self.__registry.update(identity))
        if metadata[0] != identity:
            raise OSError("Identity doesn't match stream %s" % identity)
        stream = DataStream(self, self.load_block(metadata[1]), *metadata)
        self.__registry.trash(stream)
        del stream
        self.__registry.unregister(identity)
        return True