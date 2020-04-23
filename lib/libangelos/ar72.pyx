# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Archive7 NG

Next generation of Archive7 containing three layers.

a) transparent encryption layer
b) on-disk nested linked lists
c) BTree indexed file system

In future C implementation, use BTree for entries:
https://github.com/antirez/otree
"""
import fcntl
import hashlib
import math
import os
import random
import struct
from abc import ABC, abstractmethod
from collections.abc import Iterable, Reversible
from io import RawIOBase, SEEK_SET, SEEK_END, SEEK_CUR

import libnacl.secret


# FIXME: Use pythons built in cache for optimization.
#  https://docs.python.org/3.4/library/functools.html#functools.lru_cache


class BaseHeap(ABC):
    pass


class BaseFileObject(ABC, RawIOBase):
    """FileIO-compliant and transparent abstract file object layer."""

    def __init__(self, file: str, mode: str = "r"):
        self.__name = file
        self.__mode = mode
        self.__readable = False
        self.__writable = False
        self.__seekable = True

        if not (len(mode) != len(set(mode)) and len(set(mode) - set("abrwx+")) == 0):
            raise ValueError("Invalid mode: %s." % mode)

        self.seek(0)
        if "a" in mode:
            self.__mode = "ab"
            self.__writable = True
            self.seek(0, SEEK_END)
        elif "w" in mode:
            self.__mode = "wb"
            self.__writable = True
        elif "r" in mode:
            self.__mode = "rb"
            self.__readable = True
        elif "x" in mode:
            self.__mode = "xb"
            self.__writable = True

        if "+" in mode:
            self.__mode += "+"
            self.__writable = True
            self.__readable = True

    def __is_closed(self):
        if self.closed:
            raise ValueError()

    def __is_readable(self):
        if not self.__readable:
            raise OSError()

    def __is_writable(self):
        if not self.__writable:
            raise OSError()

    def __is_seekable(self):
        if not self.__seekable:
            raise OSError()

    @property
    def name(self):
        """Name of the file a string."""
        return self.__name

    @property
    def mode(self):
        """File mode as string."""
        return self.__mode

    def close(self):
        """
        Flush and close the IO object.

        This method has no effect if the file is already closed.
        """
        if not self.closed:
            super().close(self)
            self._close()

    def fileno(self):
        """
        Return underlying file descriptor (an int) if one exists.

        An OSError is raised if the IO object does not use a file descriptor.
        """
        raise OSError()

    def flush(self):
        """
        Flush write buffers, if applicable.

        This is not implemented for read-only and non-blocking streams.
        """
        super().flush(self)
        self._flush()

    @abstractmethod
    def _flush(self):
        pass

    def isatty(self):
        """Return true if the file is connected to a TTY device."""
        self.__is_closed()
        return False

    def readinto(self, b):
        """
        Read bytes into a pre-allocated bytes-like object b.

        Returns an int representing the number of bytes read (0 for EOF), or
        None if the object is set not to block and has no data to read.
        """
        self.__is_closed()
        self.__is_readable()

        return self._readinto(b)

    @abstractmethod
    def _readinto(self, b):
        pass

    def readable(self):
        """Return true if file was opened in a read mode."""
        self.__is_closed()
        return self.__readable

    def seek(self, offset, whence=SEEK_SET):
        """
        Change stream position.

        Change the stream position to byte offset pos. Argument pos is
        interpreted relative to the position indicated by whence.  Values
        for whence are ints:
        * 0 -- start of stream (the default); offset should be zero or positive
        * 1 -- current stream position; offset may be negative
        * 2 -- end of stream; offset is usually negative
        Some operating systems / file systems could provide additional values.
        Return an int indicating the new absolute position.
        """
        self.__is_closed()
        self.__is_seekable()

        return self._seek(offset, whence)

    @abstractmethod
    def _seek(self, offset, whence):
        pass

    def seekable(self):
        """Return true if file supports random-access."""
        self.__is_closed()
        return self.__seekable

    def tell(self):
        """Tell current IO position."""
        self.__is_seekable()

        return self.__position

    def truncate(self, size=None):
        """
        Truncate file to size bytes.

        Size defaults to the current IO position as reported by tell(). Return
        the new size.
        """
        self.__is_closed()
        self.__is_writable()
        self.__is_seekable()

        self._truncate(size)

    @abstractmethod
    def _truncate(self, size):
        pass

    def writable(self):
        """If file is writable, returns True, else False."""
        self.__is_closed()
        return self.__writable

    def write(self, b):
        """
        Write the given buffer to the IO stream.

        Returns the number of bytes written, which may be less than the
        length of b in bytes.
        """
        self.__is_closed()
        self.__is_writable()

        return self._write(b)

    @abstractmethod
    def _write(self, b):
        pass


BLOCK_SIZE = 4096
DATA_SIZE = 4020
MAX_UINT32 = 2**32


class StreamBlock:
    """A block of data in a stream.

    The amount of raw data is set to 4020 bytes, except 16 bytes for metadata and 20 bytes of digest.
    This sums up to 4056 bytes, after encryption and its digest we end up with 4096 bytes or 4 Kb.

        self.previous. 4 bytes, signed integer linking to previous block.
        self.next. 4 bytes, signed integer linking to next block.
        self.index. 4 bytes, unsigned integer block in stream index.
        self.stream. 4 bytes, unsigned integer setting stream id.
        self.digest. 20 bytes, sha1 digest of the data field.
        self.data. 4020 bytes
    """

    FORMAT = "!iiII20s4020s"

    def __init__(self, position: int = None, previous: int = -1, next: int = -1, index: int = 0, stream: int = 0,
                 block: bytes = None):
        self.__position = position

        self.previous = previous
        self.next = next
        self.index = index
        self.stream = stream
        self.digest = None
        self.data = bytearray(DATA_SIZE)

        if block:
            self.load(block)

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
        (
            self.previous, self.next, self.index, self.stream, self.digest, data
        ) = struct.unpack(StreamBlock.FORMAT, block)
        if hashlib.sha1(self.data).digest() != self.digest:
            valid = False
            # raise ValueError("Loaded data chunk is corrupt.")

        self.data[:] = data[:]
        return valid

    def __bytes__(self) -> bytes:
        return struct.pack(
            StreamBlock.FORMAT,
            self.previous,
            self.next,
            self.index,
            self.stream,
            hashlib.sha1(self.data).digest(),
            self.data
        )


class DataStream(Iterable, Reversible):
    """Descriptor for an open data stream to be read and written too.

    Data streams should be wrapped in a file descriptor.

        self.__identity. unsigned integer, the id number of the stream in the registry.
        self.__begin. signed integer, position of the first block in the stream.
        self.__end. signed integer, position of the last block in the stream.
        self.__count. unsigned integer, number of blocks used.
        self.__length. unsigned long long, number of bytes in the data stream.
        self.__compression, unsigned short, compression algorithm of choice.
    """

    COMP_NONE = 0

    FORMAT = "!iIIiQH"

    def __init__(self, manager: "StreamManager", block: StreamBlock, identity: int, begin: int = -1,
                 end: int = -1, count: int = 0, length: int = 0, compression: int = 0):
        self.__manager = manager
        self.__block = block
        self.__changed = False
        block.stream = identity

        self._identity = identity
        self._begin = begin
        self._end = end
        self._count = count
        self._length = length
        self._compression = compression

    @property
    def data(self):
        """Expose the current block's data section."""
        return self.__block.data

    def load_meta(self, stream: bytes) -> bool:
        """Unpack metadata and populate the fields.

        Args:
            block (bytes):
                Bytes to be read into metadata.

        Returns (bool):
            True if the loaded data is not corrupt else False

        """
        (
            self._identity, self._begin, self._end, self._count, self._length, self._compression
        ) = struct.unpack(StreamBlock.FORMAT, stream)
        return True

    def __bytes__(self):
        return struct.pack(
            DataStream.FORMAT,
            self._identity,
            self._begin,
            self._end,
            self._count,
            self._length,
            self._compression
        )

    def __iter__(self):
        forward = True
        if self.__block.position != self._begin:
            self.__manager.save_block(self.__block)
            self.__block = self.__manager.load_block(self._begin)

        while forward:
            forward = self.next()
            yield bytes(self.__block.data)

    def __reversed__(self):
        backward = True
        if self.__block.position != self._end:
            self.__manager.save_block(self.__block)
            self.__block = self.__manager.load_block(self._end)

        while backward:
            backward = self.previous()
            yield bytes(self.__block.data)

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
            self.__manager.save_block(self.__block.position, self.__block)
            self.__changed = False

    def next(self) -> bool:
        """Load next data block in the stream.

        Returns (bool):
            True if next block loads, if it is last block False.

        """
        return self.__step(self.__block.next)

    def previous(self) -> bool:
        """Load previous data block in the stream.

        Returns (bool):
            True if previous block loads, if it is last block False.

        """
        return self.__step(self.__block.previous)

    def __step(self, to: int):
        if to == -1:
            return False
        else:
            block = self.__manager.load_block(to)
            self.save()
            self.__block = block
            return True

    def extend(self) -> bool:
        """Create a new block at the end of stream.

        Returns (bool):
            True if successfully created a new block or False if not at end of stream.

        """
        if self.__block.next != -1:
            return False
        else:
            block = self.__manager.new_block()
            block.index = self._count  # The current count is the same as the new index
            block.stream = self._identity
            block.previous = self.__block.position
            self.__block.next = block.position
            self._end = block.position
            self._count += 1  # Update the count after indexing
            self.save()
            self.__block = block
            return True

    def truncate(self, length: int) -> int:
        """Truncate the stream to a certian length and recycle blocks.

        Args:
            length (int):
                New length of stream.

        Returns (int):
            New length of stream.

        """
        index = math.floor(length / DATA_SIZE)
        offset = length % DATA_SIZE
        remnant = DATA_SIZE - offset

        self.save()
        self.wind(index)

        self.__block.data[offset:] = b"\x00" * remnant
        self.save(True)

        self._end = self.__block.position
        self._count = self.__block.index + 1
        self._length = length

        if self.__block.next != -1:
            next = self.__block.next

            self.__block.next = -1
            self.save(True)

            block = self.__manager.load_block(next)
            block.previous = -1
            self.__manager.save_block(block.position, block)
            self.__manager.trash(block)

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
        current = self.__block

        if self.__block.index > index:  # Go forward
            while self.next():
                if self.__block.index == index:
                    pos = index
                    break
        elif self.__block.index < index:  # Go backward
            while self.previous():
                if self.__block.index == index:
                    pos = index
                    break

        if pos == -1:
            self.__block = current

        return pos


class VirtualFileObject(BaseFileObject):
    """Stream for the registry index database."""

    def __init__(self, stream: DataStream, file: str, mode: str = "r"):
        self.__stream = stream
        self.__position = 0
        self.__offset = 0
        self.__end = stream.length()
        BaseFileObject.__init__(file, mode)

    def _flush(self):
        self.__stream.save(True)

    def _readinto(self, b):
        m = memoryview(b).cast("B")
        size = min(len(m), self.__end - self.__position)

        data = bytearray()
        cursor = 0
        # FIXME: Save data here?

        while size > cursor:
            num_copy = min(DATA_SIZE - self.__offset, size - cursor)

            data += self.__stream.data[self.__offset:self.__offset + num_copy]
            cursor += num_copy
            self.__position += num_copy
            self.__offset += num_copy

            if self.__offset == DATA_SIZE:
                self.__stream.next()
                self.__offset = 0

        n = len(data)
        m[:n] = data
        return n

    def _seek(self, offset, whence):
        if whence == SEEK_SET:
            cursor = min(max(offset, 0), self.__end)
        elif whence == SEEK_CUR:
            if offset < 0:
                cursor = max(self.__position + offset, 0)
            else:
                cursor = min(self.__position + offset, self.__end)
        elif whence == SEEK_END:
            cursor = max(min(self.__end + offset, self.__end), 0)
        else:
            raise OSError("Invalid seek, %s" % whence)

        block = int(math.floor(cursor / DATA_SIZE))
        if self.__stream.wind(block) != block:
            return self.__position
        else:
            self.__offset = cursor - (block * DATA_SIZE)
            self.__position = cursor
            return self.__position

    def _truncate(self, size):
        if size:
            self.__stream.truncate(size)
            self.__end = size
        else:
            self.__stream.truncate(self.__position)
            self.__end = self.__position
        return self.__end

    def _write(self, b):
        write_len = len(b)
        if not write_len:
            return 0

        cursor = 0

        while write_len > cursor:
            self.__stream.changed()
            num_copy = min(DATA_SIZE - self._offset, write_len - cursor)

            self.__stream.data[self.__offset:self.__offset + num_copy] = b[cursor:cursor + num_copy]

            cursor += num_copy
            self.__position += num_copy
            self.__offset += num_copy
            if self.__position > self.__end:  # Updating stream length
                self.__stream.length(self.__position - self.__end)
                self.__end = self.__position

            if self.__offset >= DATA_SIZE:  # Load next or new block
                if not self.__stream.next():
                    if not self.__stream.extend():
                        raise OSError("Out of space.")
                self.__offset = 0

        return cursor if cursor else None


class IndexStream:
    pass


class TrashStream:
    pass


class StreamRegistry:

    FORMAT = "!i"

    def __init__(self, manager: "StreamManager"):
        self.__manager = manager
        self.__index = None
        self.heap = []
        self.entries = 0

        self.__open_index()
        self.__open_trash()

    def load(self, block: bytes):
        pass

    def __bytes__(self):
        pass

    def __open_index(self):
        identity = 0
        block = self.__manager.special_block(StreamManager.BLOCK_INDEX)
        stream = DataStream(self.__manager, block, StreamManager.STREAM_INDEX, begin=block.position)

    def __open_trash(self):
        pass


class StreamManager(ABC):
    """Stream manager handles all the streams and blocks that are underlying of a virtual file system.

    The underlying system is built up of 4Kb blocks that can be chained like linked lists, those are data streams.
    There can be and are several data streams, they can be used for files and can expand by adding more blocks,
    thanks to this streams can grow in size.

    There are reserved blocks and streams. In total the first eight blocks are reserved, so are the first eight
    streams.
    """

    BLOCK_META = 0
    BLOCK_OP = 1
    BLOCK_SWAP1 = 2
    BLOCK_SWAP2 = 3
    BLOCK_SWAP3 = 4
    BLOCK_DATA = 5
    BLOCK_INDEX = 6
    BLOCK_TRASH = 7

    STREAM_INDEX = 0
    STREAM_TRASH = 1

    def __init__(self, filename: str, secret: bytes):
        # Filename and path
        self.__filename = filename
        # Encryption secret
        self.__secret = secret

        # Archive file descriptor
        self.__file = None
        # Encryption/decryption object
        self.__box = libnacl.secret.SecretBox(secret)

        # Number of blocks in archive
        self.__count = 0

        # Reserved blocks
        self.__blocks = None
        # Reserved streams
        self.__streams = dict()
        # Currently open streams
        self.__open = set()

        dirname = os.path.dirname(filename)
        if not os.path.isdir(dirname):
            raise OSError("Directory %s doesn't exist." % dirname)

        if os.path.isfile(filename):
            # Open and use file
            self.__open()
        else:
            # Initialize file before using
            self.__setup()

        fcntl.flock(self.__file, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def __get_size(self) -> int:
        """Size of the underlying file.

        Returns (int):
            Length of file.

        """
        self.__file.seek(0, os.SEEK_END)
        return self.__file.tell()

    def __setup(self):
        self.__file = open(self.__filename, "ab+", BLOCK_SIZE)
        self.__blocks = {i:self.new_block() for i in range(8)}
        self.__start_core()
        self.__save_data()

    def __open(self):
        self.__file = open(self.__filename, "rb+", BLOCK_SIZE)
        position = self.__get_size()
        if position % BLOCK_SIZE:
            raise OSError("Archive length uneven to block size.")
        self.__count = int(position / BLOCK_SIZE)
        self.__blocks = {i:self.load_block() for i in range(8)}
        self.__start_core()
        self.__load_data()

    def __close(self):
        self.__streams[StreamManager.STREAM_INDEX].save(True)
        self.__streams[StreamManager.STREAM_TRASH].save(True)
        self.__save_data()

    def __start_core(self):
        self.__streams[StreamManager.STREAM_INDEX] = DataStream(
            self, self.__blocks[StreamManager.BLOCK_INDEX], StreamManager.STREAM_INDEX)
        self.__streams[StreamManager.STREAM_TRASH] = DataStream(
            self, self.__blocks[StreamManager.BLOCK_INDEX], StreamManager.STREAM_TRASH)

    def __load_data(self):
        size = struct.calcsize(StreamBlock.FORMAT)
        data = self.__block[StreamManager.BLOCK_DATA]
        self.__streams[StreamManager.STREAM_INDEX].load_meta(data.data[:size])
        self.__streams[StreamManager.STREAM_TRASH].load_meta(data.data[size:size*2])

    def __save_data(self):
        size = struct.calcsize(StreamBlock.FORMAT)
        data = self.__block[StreamManager.BLOCK_DATA]
        data.data[:size] = bytes(self.__streams[StreamManager.STREAM_INDEX])
        data.data[size:size*2] = bytes(self.__streams[StreamManager.STREAM_TRASH])
        self.save_block(data.position, data)

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
        self.__file.seek(0, os.SEEK_END)
        block = StreamBlock(position=self.__count)
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
        if index >= self.__count:
            raise IndexError("Index out of bounds, %s of %s." % (index, self.__blocks))

        position = index % BLOCK_SIZE
        offset = self.__file.seek(position)
        if not position == offset:
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
        if index != block.position:
            raise IndexError("Index %s and position %s are not the same." % (index, block.position))

        position = index % BLOCK_SIZE
        offset = self.__file.seek(position)
        if not position == offset:
            raise OSError("Failed to seek for position %s, ended at %s." % (position, offset))

        length = self.__file.write(self.__box.encrypt(block))

        if length != BLOCK_SIZE:
            raise OSError("Failed writing full block, wrote %s bytes instead of %s." % (length, BLOCK_SIZE))

    def new_stream(self) -> DataStream:
        """Create a new data stream.

        Returns (DataStream):
            The new data stream created.

        """
        identity = random.random(8, MAX_UINT32)  # FIXME: Generate identity in registry instead.
        block = self.new_block(index=0, stream=identity)
        stream = DataStream(self, block, identity, begin=block.position, end=block.position, count=1)
        self.__registry.register(stream)
        self.__streams.add(stream)
        return stream

    def open_stream(self, stream: int) -> DataStream:
        """Open an existing data stream.

        Args:
            stream (int):
                Data stream number.

        Returns (DataStream):
            The opened data stream object.

        """
        pass

    def close_stream(self, stream: DataStream):
        """Close an open data stream.

        Args:
            stream (DataStream):
                Data stream object being saved.

        """
        pass

    def del_stream(self, stream: int) -> bool:
        """Delete data stream from file.

        Args:
            stream (int):
                Data stream number to be erased.

        Returns (bool):
            Success of deleting data stream.

        """
        pass

    def __del__(self):
        if not self.__file.closed:
            fcntl.flock(self.__file, fcntl.LOCK_UN)
            self.__file.close()


class FilesystemMixin:
    """Mixin for all essential function calls for a file system."""

    def access(self, path, mode, *, dir_fd=None, effective_ids=False, follow_symlinks=True):
        raise NotImplementedError()

    def chflags(self, path, flags, *, follow_symlinks=True):
        raise NotImplementedError()

    def chmod(self, path, mode, *, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def chown(self, path, uid, gid, *, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def lchflags(self, path, flags):
        raise NotImplementedError()

    def lchmod(self, path, mode):
        raise NotImplementedError()

    def lchown(self, path, uid, gid):
        raise NotImplementedError()

    def link(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def listdir(self, path="."):
        raise NotImplementedError()

    def lstat(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def mkdir(self, path, mode=0o777, *, dir_fd=None):
        raise NotImplementedError()

    def makedirs(self, name, mode=0o777, exist_ok=False):
        raise NotImplementedError()

    def mkfifo(self, path, mode=0o666, *, dir_fd=None):
        raise NotImplementedError()

    def readlink(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def remove(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def removedirs(self, name):
        raise NotImplementedError()

    def rename(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None):
        raise NotImplementedError()

    def renames(self, old, new):
        raise NotImplementedError()

    def replace(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None):
        raise NotImplementedError()

    def rmdir(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def scandir(self, path="."):
        raise NotImplementedError()

    def stat(self, path, *, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def symlink(self, src, dst, target_is_directory=False, *, dir_fd=None):
        raise NotImplementedError()

    def sync(self):
        raise NotImplementedError()

    def truncate(self, path, length):
        raise NotImplementedError()

    def unlink(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def time(self, path, times=None, *, ns, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def walk(self, top, topdown=True, onerror=None, followlinks=False):
        raise NotImplementedError()

    def fwalk(self, top=".", topdown=True, onerror=None, *, follow_symlinks=False, dir_fd=None):
        raise NotImplementedError()


class AbstractVirtualFilesystem(FilesystemMixin):
    """Abstract class for a virtual file system."""

    def __init__(self):
        pass

    def unmount(self):
        pass


class AbstractFilesystemSession(FilesystemMixin):
    """Abstract class for a file system session. (current directory support)."""
    def __init__(self):
        pass

    def chdir(self, path):
        pass

    def chroot(self, path):
        pass

    def fchdir(self, fd):
        pass

    def getcwd(self):
        pass

    def getcwdb(self):
        pass