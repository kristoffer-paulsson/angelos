# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Conceal is transparent file encryption.
"""
import io
import os
import math
import struct
import fcntl

import libnacl.secret

from ..utils import Util
from ..error import Error


class ConcealIO(io.RawIOBase):
    """ConcealIO is a FileIO-compliant and transparent encryption layer."""

    TOT_SIZE = 512*33
    CBLK_SIZE = 512*32 + 40
    ABLK_SIZE = 512*32

    def __init__(self, file, mode='rb', secret=None):
        """Init with file object, mode and symmetric encryption key."""
        Util.is_type(file, (str, bytes, io.IOBase))
        Util.is_type(mode, (str, bytes))
        Util.is_type(secret, (str, bytes))

        if isinstance(file, io.IOBase):
            if file.mode not in ['rb', 'rb+', 'wb']:
                raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
            self._name = file.name
            self._mode = file.mode
            self._fd = file
            self._fdclose = False
        else:
            if mode not in ['rb', 'rb+', 'wb']:
                raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
            self._name = file
            self._mode = mode
            self._fd = open(file, mode)
            self._fdclose = True

        self._readable = True if mode in ['rb', 'rb+'] else False
        self._writable = True if mode in ['wb', 'rb+'] else False
        self._seekable = True if mode in ['rb', 'rb+', 'wb'] else False

        self._closed = False

        fcntl.flock(self._fd, fcntl.LOCK_EX | fcntl.LOCK_NB)

        self._box = libnacl.secret.SecretBox(secret)
        self._count = int(os.fstat(
            self._fd.fileno()).st_size / ConcealIO.TOT_SIZE)
        self._end = 0 if self._count == 0 else self.__length()
        self._size = self._count * ConcealIO.ABLK_SIZE
        self._index = 0
        self._position = 0
        self._offset = 0
        self._changed = False
        self._buffer = None

        if self._count:
            self._load(0)
        else:
            self._new()

    def __length(self, offset=None):
        Util.is_type(offset, (int, type(None)))

        realpos = self._fd.tell()
        self._fd.seek(ConcealIO.CBLK_SIZE)

        if offset is None:
            data = self._box.decrypt(self._fd.read(48))
            offset = struct.unpack('!Q', data)[0]
        elif self._mode in ['rb+', 'wb']:
            data = bytearray(self._box.encrypt(
                struct.pack('!Q', offset)) + os.urandom(424))
            self._fd.write(data)

        self._fd.seek(realpos)
        return offset

    def _new(self):
        blk = self._count
        pos = blk * ConcealIO.TOT_SIZE
        res = self._fd.seek(pos)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        self._buffer = bytearray().ljust(ConcealIO.ABLK_SIZE, b'\x00')

        if blk == 0:
            filler = b''
        else:
            filler = os.urandom(472)
        block = bytearray(
            self._box.encrypt(self._buffer) + filler)
        self._fd.write(block)

        self._count += 1
        self._index = blk
        self._changed = False
        return True

    def _load(self, blk):
        if not self._count > blk:
            raise IndexError('Block out of range.')

        pos = blk * ConcealIO.TOT_SIZE
        res = self._fd.seek(pos)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        self._buffer = bytearray(self._box.decrypt(
            self._fd.read(ConcealIO.CBLK_SIZE)))

        self._index = blk
        self._changed = False
        return True

    def _save(self):
        if not self._changed:
            return False

        pos = self._index * ConcealIO.TOT_SIZE
        res = self._fd.seek(pos)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        if self._index == 0:
            filler = b''
        else:
            filler = os.urandom(472)
        block = bytearray(
            self._box.encrypt(self._buffer) + filler)
        self._fd.write(block)

        if self._index >= self._count:
            self.__blk_cnt = self._index + 1
            self._size = self._count * ConcealIO.TOT_SIZE

        self._changed = False
        return True

    @property
    def name(self):
        """Name of the file a string."""
        return self._name

    @property
    def mode(self):
        """File mode as string."""
        return self._mode

    @property
    def closed(self):
        """Mode property."""
        return self._closed

    def close(self):
        """
        Flush and close the IO object.

        This method has no effect if the file is already closed.
        """
        if not self.closed:
            self._closed = True
            self._save()
            self.__length(self._end)
            fcntl.flock(self._fd, fcntl.LOCK_UN)
            io.RawIOBase.close(self)
            if self._fdclose:
                self._fd.close()

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
        self._save()
        self.__length(self._end)
        io.RawIOBase.flush(self)
        self._fd.flush()

    def isatty(self):
        """Return true if the file is connected to a TTY device."""
        if self.closed:
            raise ValueError()
        return False

    def readinto(self, b):
        """
        Read bytes into a pre-allocated bytes-like object b.

        Returns an int representing the number of bytes read (0 for EOF), or
        None if the object is set not to block and has no data to read.
        """
        if self.closed:
            raise ValueError()
        if not self.readable():
            raise OSError()

        m = memoryview(b).cast('B')
        size = min(len(m), self._end - self._position)

        data = bytearray()
        cursor = 0
        self._save()

        while size > cursor:
            numcpy = min(
                ConcealIO.ABLK_SIZE - self._offset, size - cursor)

            data += self._buffer[self._offset:self._offset+numcpy]
            cursor += numcpy
            self._position += numcpy
            self._offset += numcpy

            if self._offset == ConcealIO.ABLK_SIZE:
                self._load(self._index + 1)
                self._offset = 0

        n = len(data)
        m[:n] = data
        return n

    def readable(self):
        """Return true if file was opened in a read mode."""
        if self.closed:
            raise ValueError()
        return self._readable

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
        if self.closed:
            raise ValueError()
        if not self.seekable():
            raise OSError()

        if whence == io.SEEK_SET:
            cursor = min(max(offset, 0), self._end)
        elif whence == io.SEEK_CUR:
            if offset < 0:
                cursor = max(self._position + offset, 0)
            else:
                cursor = min(self._position + offset, self._end)
        elif whence == io.SEEK_END:
            cursor = max(min(self._end + offset, self._end), 0)
        else:
            raise Util.exception(Error.CONCEAL_INVALID_SEEK, {
                'whence': whence})

        blk = int(math.floor(cursor / self.ABLK_SIZE))
        if self._index != blk:
            self._save()
            self._load(blk)

        self._offset = cursor - (blk * self.ABLK_SIZE)
        self._position = cursor
        return self._position

    def seekable(self):
        """Return true if file supports random-access."""
        if self.closed:
            raise ValueError()
        return self._seekable

    def tell(self):
        """Tell current IO position."""
        if not self.seekable():
            raise OSError()

        return self._position

    def truncate(self, size=None):
        """
        Truncate file to size bytes.

        Size defaults to the current IO position as reported by tell(). Return
        the new size.
        """
        if self.closed:
            raise ValueError()
        if not self.writable():
            raise OSError()
        if not self.seekable():
            raise OSError()

        if size:
            blk = int(math.floor(size / self.ABLK_SIZE))
            if self._index != blk:
                self._save()
                self._load(blk)
            blk_cursor = size - (blk * self.ABLK_SIZE)
            self._end = size
        else:
            blk_cursor = self._offset
            self._end = self._position

        self._changed = True
        space = ConcealIO.ABLK_SIZE - blk_cursor
        self._buffer[self._offset:ConcealIO.ABLK_SIZE] = b'\x00' * space
        self._save()
        self._count = self._index+1

        self.__length(self._end)
        self._fd.truncate(self._count * ConcealIO.TOT_SIZE)

    def writable(self):
        """If file is writable, returns True, else False."""
        if self.closed:
            raise ValueError()
        return self._writable

    def write(self, b):
        """
        Write the given buffer to the IO stream.

        Returns the number of bytes written, which may be less than the
        length of b in bytes.
        """
        if self.closed:
            raise ValueError()
        if not self.writable():
            raise OSError()

        Util.is_type(b, (bytes, bytearray, memoryview))

        wrtlen = len(b)
        if not wrtlen:
            return 0

        cursor = 0

        while wrtlen > cursor:
            self._changed = True
            numcpy = min(
                ConcealIO.ABLK_SIZE - self._offset, wrtlen - cursor)

            self._buffer[
                self._offset:self._offset + numcpy] = b[
                    cursor: cursor + numcpy]  # noqa E501

            cursor += numcpy
            self._offset += numcpy
            self._position += numcpy
            if self._position > self._end:
                self._end = self._position

            if self._offset >= ConcealIO.ABLK_SIZE:
                self._save()
                self.__length(self._end)
                next = self._index + 1
                if self._count == next:
                    self._new()
                else:
                    self._load(next)
                self._offset = 0

        return cursor if cursor else None
