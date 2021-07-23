# cython: language_level=3, linetrace=True
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Base classes."""
import struct
from abc import ABC, abstractmethod
from collections import namedtuple
from io import RawIOBase, SEEK_SET, SEEK_END

BLOCK_SIZE = 4096
DATA_SIZE = 4008
MAX_UINT32 = 2 ** 32

FORMAT_BLOCK = "!iiI16s20s4008s"
SIZE_BLOCK = struct.calcsize(FORMAT_BLOCK)
FORMAT_STREAM = "!16siiIQH"
SIZE_STREAM = struct.calcsize(FORMAT_STREAM)

BlockTuple = namedtuple("BlockTuple", "previous next index stream digest data")


class BlockError(RuntimeError):
    """Exception for block error."""
    HEADER_REFERENCE_ERROR = ("Block header self-referencing.", 50)
    DIGEST_MISMATCH = ("Corrupt data, digest mismatch.", 51)


class StreamError(RuntimeError):
    """Exception for stream error."""
    NON_BLOCK_ERROR = ("Can not push a non-block on stream.", 60)
    PUSH_FRONT_ERROR = ("Can only push at the end of the stream.", 61)
    POP_REAR_ERROR = ("Can only pop from the end of the stream.", 62)
    POP_NOT_LAST_ERROR = ("Can not pop last block off of stream.", 63)
    OUT_OF_BOUNDS = ("Index out of bounds.", 64)
    POP_READ_ERROR = ("Can only pop from the end of the stream.", 65)


class StreamManagerError(RuntimeError):
    """Exception for stream manager error."""
    UNEVEN_ARCHIVE_LENGTH = ("Archive length uneven to block size.", 80)
    CORRUPT_STREAM_IDENTIFIER = ("Corrupt internal stream identifier", 81)
    SPECIAL_BLOCK_BOUNDARY = ("Index must be within defined boundaries.", 82)
    FAILED_FULL_WRITE = ("Failed writing full block.", 83)
    OUT_OF_BOUNDS = ("Index out of bounds.", 84)
    BLOCK_SEEK_ERROR = ("Failed to seek for position", 85)
    SPECIAL_STREAM_BOUNDARY = ("Index must be within defined boundaries.", 86)
    INDEX_POSITION_MISMATCH = ("Index and position are not the same.", 87)
    FAILED_SEEK_POSITION = ("Failed to seek for position.", 88)
    ALREADY_OPEN = ("Already opened", 89)
    NO_STREAM_IDENTITY = ("Identity doesn't exist", 90)
    NOT_OPEN = ("Stream not known to be open.", 91)


class BaseFileObject(ABC, RawIOBase):
    """FileIO-compliant and transparent abstract file object layer."""

    __slots__ = ["__name", "__mode", "__readable", "__writable", "__seekable"]

    def __init__(self, filename: str, mode: str = "r"):
        self.__name = filename
        self.__mode = mode
        self.__readable = False
        self.__writable = False
        self.__seekable = True

        if not (len(mode) == len(set(mode)) and len(set(mode) - set("abrwx+")) == 0):
            raise OSError("Invalid mode: %s." % mode)

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
            raise OSError()

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
            RawIOBase.close(self)
            self._close()

    @abstractmethod
    def _close(self):
        pass

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

        return self._position

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
