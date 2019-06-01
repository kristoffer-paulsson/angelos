"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Conceal is transparent file encryption."""
import io
import os
import math
import struct

import libnacl

from ..utils import Util
from ..error import Error


class ConcealIO(io.RawIOBase):
    """ConcealIO is a FileIO-compliant and transparent encryption layer."""

    TOT_SIZE = 512*33
    CBLK_SIZE = 512*32 + 40
    ABLK_SIZE = 512*32

    def __init__(self, file, mode='rb', secret=None):
        """Init with file object, mode and symmetric encryption key."""
        Util.is_type(file, (str, bytes, io.FileIO))
        Util.is_type(mode, (str, bytes))
        Util.is_type(secret, (str, bytes))

        # if isinstance(file, io.FileIO):
        #    if file.mode not in ['rb', 'rb+', 'wb']:
        #        raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
        #    self._fd = file
        #    self._closefd = False
        # else:
        if mode not in ['rb', 'rb+', 'wb']:
            raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
        if mode == 'wb':
            open(file, 'a').close()

        self._mode = mode
        self._fd = open(file, 'rb+')
        self._closefd = True

        self._readable = True if self._fd.mode in ['rb', 'rb+'] else False
        self._writable = True if self._fd.mode in ['wb', 'rb+'] else False
        self._seekable = True if self._fd.mode in ['rb+'] else False

        # fcntl.flock(self._fd, fcntl.LOCK_EX | fcntl.LOCK_NB)

        self._box = libnacl.secret.SecretBox(secret)  # Encryption box
        self._count = int(os.fstat(  # Block count
            self._fd.fileno()).st_size / ConcealIO.TOT_SIZE)
        self._end = 0 if self._count == 0 else self.__length()  # Data size
        self._size = self._count * ConcealIO.ABLK_SIZE  # Real filesize
        self._index = 0  # Current loaded block
        self._position = 0  # Cursor in file
        self._offset = 0  # Cursor in current block
        self._changed = False  # Buffer needs to flush
        self._buffer = None  # Buffer itself

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
        elif self._fd.mode in ['rb+', 'wb']:
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
        block = bytearray(self._box.encrypt(self._buffer) + filler)
        self._fd.write(block)

        if self._index >= self._count:
            self.__blk_cnt = self._index + 1
            self._size = self._count * ConcealIO.TOT_SIZE

        self._changed = False
        return True

    def readable(self):
        """Return true if file was opened in a read mode."""
        self._checkClosed()
        # return self._fd.readable()
        return self._readable

    def writable(self):
        """Return true if file was opened in a write mode."""
        self._checkClosed()
        # return self._fd.writable()
        return self._writable

    def seekable(self):
        """Return true if file supports random-access."""
        self._checkClosed()
        # return self._fd.seekable()
        return self._seekable

    def seek(self, offset, whence=0):
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
        if isinstance(offset, float):
            raise TypeError('an integer is required')
        self._checkClosed()
        if not self._seekable:
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

    def truncate(self, size=None):
        """
        Truncate file to size bytes.

        Size defaults to the current IO position as reported by tell(). Return
        the new size.
        """
        self._checkClosed()
        self._checkWritable()

        if size is None:
            size = self.tell()

        blk = int(math.floor(size / self.ABLK_SIZE))
        if self._index != blk:
            self._save()
            self._load(blk)
        blk_cursor = size - (blk * self.ABLK_SIZE)
        self._end = size

        self._changed = True
        space = ConcealIO.ABLK_SIZE - blk_cursor
        self._buffer[self._offset:ConcealIO.ABLK_SIZE] = b'\x00' * space
        self._save()
        self._count = self._index+1

        self.__length(self._end)
        self._fd.truncate(self._count * ConcealIO.TOT_SIZE)

        return size

    def readinto(self, b):
        """
        Read bytes into a pre-allocated bytes-like object b.

        Returns an int representing the number of bytes read (0 for EOF), or
        None if the object is set not to block and has no data to read.
        """
        self._checkClosed()
        self._checkReadable()

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

    def write(self, b):
        """
        Write the given buffer to the IO stream.

        Returns the number of bytes written, which may be less than the
        length of b in bytes.
        """
        self._checkClosed()
        self._checkWritable()

        try:
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
                        cursor: cursor + numcpy]

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

            return cursor
        except BlockingIOError:
            return None

    def fileno(self):
        """
        Return underlying file descriptor (an int) if one exists.

        An OSError is raised if the IO object does not use a file descriptor.
        """
        self._checkClosed()
        return self._fd.fileno()

    def isatty(self):
        """Return true if the file is connected to a TTY device."""
        self._checkClosed()
        return False

    def flush(self):
        """
        Flush write buffers, if applicable.

        This is not implemented for read-only and non-blocking streams.
        """
        self._checkClosed()
        self._save()
        # self._fd.flush()

    def close(self):
        """
        Flush and close the IO object.

        This method has no effect if the file is already closed.
        """
        if not self.closed:
            try:
                if self._closefd:
                    self._save()
                    self.__length()
                    self._fd.close()
            finally:
                super().close()

    @property
    def name(self):
        """Name of the file a string."""
        return self._fd.name

    @property
    def mode(self):
        """File mode as string."""
        return self._mode
