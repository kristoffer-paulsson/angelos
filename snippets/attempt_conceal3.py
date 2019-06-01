"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Conceal is transparent file encryption."""
import io
import os
import math

import libnacl

from ..utils import Util
from ..error import Error


DEFAULT_BUFFER_SIZE = 227 * 72
REAL_BUFFER_SIZE = DEFAULT_BUFFER_SIZE + 40


class ConcealIO2(_pyio.FileIO):
    def __init__(self, file, mode='r', closefd=True, opener=None, secret=None):
        if not secret:
            raise ValueError('No secret for encryption.')

        _pyio.FileIO.__init__(
            self, file=file, mode=mode, closefd=True, opener=None)

        self._box = libnacl.secret.SecretBox(secret)    # Encryption box
        self._size = 0          # Real filesize
        self._count = 0         # Block count
        self._partial = False   # Last block partial
        self._index = 0         # Current loaded block
        self._offset = 0        # Position in current block
        self._position = 0      # Total position
        self._remainder = 0     # Size of last block if less than full size
        self._end = 0           # The lengh of accessible data
        self._changed = False      # Buffer needs to flush
        self._buffer = None     # Buffer itself

        self._length()

        if self._count:
            if self._appending:
                self._load(self._count - 1)
            else:
                self._load(0)
        else:
            self._new()

        if self._appending:
            pass  # Seek to end

    def _length(self):
        self._size = os.fstat(self._fd).st_size
        self._count = math.ceil(self._size / REAL_BUFFER_SIZE)
        full = int(self._size / REAL_BUFFER_SIZE)
        if self._count == full:
            self._remainder = 0
            self._parital = False
            self._end = self._count * DEFAULT_BUFFER_SIZE
        else:
            self._remainder = self._size % REAL_BUFFER_SIZE - 40
            self._partial = True
            self._end = full * DEFAULT_BUFFER_SIZE + self._remainder

    def _new(self):
        block = self._count
        position = block * REAL_BUFFER_SIZE
        result = os.lseek(self._fd, position, 0)

        if position != result:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': position, 'result': result})

        self._buffer = bytearray().ljust(DEFAULT_BUFFER_SIZE, b'\x00')

        data = bytearray(self._box.encrypt(self._buffer[:self._offset]))
        os.write(self._fd, data)

        self._count += 1
        self._index = block
        self._changed = False
        return True

    def _load(self, block):

        if not self._count > block:
            raise IndexError('Block out of range.')

        position = block * REAL_BUFFER_SIZE
        result = os.lseek(self._fd, position, 0)

        if position != result:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': position, 'result': result})

        if self._count - 1 == block and self._partial:
            self._buffer = bytearray(
                self._box.decrypt(os.read(
                    self._fd, self._remainder + 40))).ljust(
                        DEFAULT_BUFFER_SIZE - self._remainder, b'\x00')
        else:
            self._buffer = bytearray(
                self._box.decrypt(os.read(self._fd, REAL_BUFFER_SIZE)))

        self._index = block
        self._changed = False
        return True

    def _save(self):
        if not self._changed:
            return False

        position = self._index * REAL_BUFFER_SIZE
        result = os.lseek(self._fd, position, 0)

        if position != result:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': position, 'result': result})

        if self._count - 1 == self._index and self._partial:
            os.write(self._fd, bytearray(
                self._box.encrypt(self._buffer[:self._remainder])))

            if self._index >= self._count:
                self._count = self._index + 1
                self._size = (
                    self._index * REAL_BUFFER_SIZE + self._remainder + 40)

        else:
            os.write(self._fd, bytearray(self._box.encrypt(self._buffer)))

            if self._index >= self._count:
                self._count = self._index + 1
                self._size = self._count * REAL_BUFFER_SIZE  # Redo for partial

        self._changed = False
        return True

    def read(self, size=-1):
        if size is None:
            size = -1
        if size < 0:
            return self.readall()
        b = bytearray(size.__index__())
        n = self.readinto(b)
        if n is None:
            return None
        del b[n:]
        return bytes(b)

    def readall(self):
        res = bytearray()
        while True:
            data = self.read(DEFAULT_BUFFER_SIZE)
            if not data:
                break
            res += data
        if res:
            return bytes(res)
        else:
            # b'' or None
            return data

    def readinto(self, b):
        self._checkClosed()
        self._checkReadable()

        try:
            m = memoryview(b).cast('B')

            data = bytearray()
            size = len(m)
            cursor = 0
            self._save()

            while size > cursor:
                numcpy = min(
                    DEFAULT_BUFFER_SIZE - self._offset, size - cursor)

                data += self._buffer[self._offset:self._offset+numcpy]
                cursor += numcpy
                self._position += numcpy
                self._offset += numcpy

                print(self._position, self._end, self._size, size, cursor)
                if self._offset == DEFAULT_BUFFER_SIZE:
                    self._load(self._index + 1)
                    self._offset = 0

            n = len(data)
            m[:n] = data
            return n
        except (BlockingIOError, IndexError):
            return None

    def write(self, b):
        self._checkClosed()
        self._checkWritable()
        try:
            cursor = 0
            save = False
            wrtlen = len(b)

            if not wrtlen:
                return 0

            while wrtlen > cursor:
                self._changed = True
                numcpy = min(
                    DEFAULT_BUFFER_SIZE - self._offset, wrtlen - cursor)

                self._buffer[self._offset:self._offset + numcpy
                             ] = b[cursor: cursor + numcpy]

                cursor += numcpy
                self._offset += numcpy
                self._position += numcpy
                if self._position > self._end:
                    self._end = self._position
                    self._remainder = self._offset
                    save = True

                if self._offset >= DEFAULT_BUFFER_SIZE:
                    self._save()
                    self._length()
                    next = self._index + 1
                    if self._count == next:
                        self._new()
                    else:
                        self._load(next)
                    self._offset = 0

            if save:
                self._save()

            return cursor
        except BlockingIOError:
            return None

    def seek(self, pos, whence=io.SEEK_SET):
        if isinstance(pos, float):
            raise TypeError('an integer is required')
        self._checkClosed()

        if whence == io.SEEK_SET:
            cursor = min(max(pos, 0), self._end)
        elif whence == io.SEEK_CUR:
            if pos < 0:
                cursor = max(self._position + pos, 0)
            else:
                cursor = min(self._position + pos, self._end)
        elif whence == io.SEEK_END:
            cursor = max(min(self._end + pos, self._end), 0)
        else:
            raise Util.exception(Error.CONCEAL_INVALID_SEEK, {
                'whence': whence})

        block = int(math.floor(cursor / DEFAULT_BUFFER_SIZE))
        if self._index != block:
            self._save()
            self._load(block)

        self._offset = cursor - (block * DEFAULT_BUFFER_SIZE)
        self._position = cursor
        return self._position

    def tell(self):
        self._checkClosed()
        return self.seek(0, io.SEEK_CUR)

    def truncate(self, size=None):
        self._checkClosed()
        self._checkWritable()
        if size is None:
            size = self.tell()

        block = int(math.floor(size / DEFAULT_BUFFER_SIZE))
        if self._index != block:
            self._save()
            self._load(block)
        self._offset = size - (block * DEFAULT_BUFFER_SIZE)
        self._remainder = self._offset
        self._end = size

        self._changed = True
        space = DEFAULT_BUFFER_SIZE - self._offset
        self.__buffer[self._offset:DEFAULT_BUFFER_SIZE] = b'\x00' * space
        self._save()
        self._count = self._index+1

        self.__length(self._end)
        os.ftruncate(
            self._fd, self._index * REAL_BUFFER_SIZE + self._remainder + 40)

        return size

    def flush(self):
        self._checkClosed()
        if self._writable:
            self._save()
            self._fd.flush()

    def close(self):
        if not self.closed:
            try:
                self.flush()
                self._fd.close()
            finally:
                super().close()
