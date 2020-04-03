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
import io
import os
import struct
from abc import ABC

import libnacl.secret


BLOCK_SIZE = 4096
DATA_SIZE = 4020


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
        self.position = position

        self.previous = previous
        self.next = next
        self.index = index
        self.stream = stream
        self.digest = None
        self.data = bytearray()

        if block:
            self.load(block)

    def load(self, block: bytes):
        """Unpack a block of bytes into its components and populate the fields

        Args:
            block (bytes):

        Returns:

        """
        data = None
        (
            self.previous, self.next, self.index, self.stream, self.digest, data
        ) = struct.unpack(StreamBlock.FORMAT, block)
        self.data = bytearray(data)

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


class DataStream:
    """Descriptor for an open data stream to be read and written too.

    Data streams should be wrapped in a file descriptor.

        self.__id. unsigned integer, the id number of the stream in the registry.
        self.__begin. signed integer, link to the first block in the stream.
        self.__end. signed integer, link to the last block in the stream.
        self.__blocks. unsigned integer, number of blocks used.
        self.__length. unsigned long long, number of bytes in the data stream.
        self.__compression, unsigned short, compression algorithm of choice.
    """

    COMP_NONE = 0

    FORMAT = "!iIIiQH"

    def __init__(self, manager: "StreamManager"):
        self.__manager = manager

        self.__id = 0
        self.__begin = -1
        self.__end = -1
        self.__blocks = 0
        self.__length = 0
        self.__compression = 0



class StreamRegistry:

    FORMAT = "!i"

    def __init__(self, manager: "StreamManager"):
        self.__manager = manager
        self.heap = []
        self.entries = 0

    def load(self, block: bytes):

        data = None
        (
            self.previous, self.next, self.index, self.stream, self.digest, data
        ) = struct.unpack(StreamBlock.FORMAT, block)
        self.data = bytearray(data)

    def __bytes__(self):
        pass


class StreamManager(ABC):
    def __init__(self, filename: str, secret: bytes):
        self.__filename = filename
        self.__secret = secret

        self.__file = None
        self.__box = libnacl.secret.SecretBox(secret)

        self.__blocks = 0

        dirname = os.path.dirname(filename)
        if not os.path.isdir(dirname):
            raise OSError("Directory %s doesn't exist." % dirname)

        self.__streams = set()
        self.__registry = None

        if os.path.isfile(filename):
            # Open and use file
            self.__file = open(filename, "rb+", BLOCK_SIZE)
            position = self.__get_size()
            if position % BLOCK_SIZE:
                raise OSError("Archive length uneven to block size.")
            self.__blocks = int(position / BLOCK_SIZE)
        else:
            # Initialize file before using
            self.__file = open(filename, "ab+", BLOCK_SIZE)

        fcntl.flock(self.__file, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def __get_size(self) -> int:
        """Size of the underlying file.

        Returns (int):
            Length of file.

        """
        self.__file.seek(0, os.SEEK_END)
        return self.__file.tell()

    def new_block(self) -> StreamBlock:
        """Create new block at the end of file, write empty block to file.

        Returns (StreamBlock):
            The newly created block.

        """
        self.__file.seek(0, os.SEEK_END)
        block = StreamBlock(position=self.__blocks)
        self.__blocks += 1
        length = self.__file.write(self.__box.encrypt(block))
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
        if index >= self.__blocks:
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
        pass

    def open_stream(self, stream: int) -> DataStream:
        """Open an existing datastream.

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
            fcntl.flock(self._file, fcntl.LOCK_UN)
            self.__file.close()


class AbstractFileObject(io.RawIOBase):
    """FileIO-compliant and transparent abstract file object layer."""

    def __init__(self, path, mode):
        self.__name = path
        self.__mode = mode
        self.__readable = False
        self.__writable = False
        self.__seekable = False
        self.__closed = False

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

    @property
    def closed(self):
        """Mode property."""
        return self.__closed

    def close(self):
        """
        Flush and close the IO object.

        This method has no effect if the file is already closed.
        """
        if not self.closed:
            super().close(self)
            self.__closed = True


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

    def readable(self):
        """Return true if file was opened in a read mode."""
        self.__is_closed()
        return self.__readable

    def seek(self, offset, whence=io.SEEK_SET):
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

        return self.__position

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