import io
import os
import fcntl
import struct
import math
import libnacl

from ..utils import Util
from ..error import Error


class ConcealIO(io.RawIOBase):
    TOT_SIZE = 512*33
    CBLK_SIZE = 512*32 + 40
    ABLK_SIZE = 512*32

    def __init__(self, path, secret, mode):
        Util.is_type(path, str)
        Util.is_type(secret, (bytes, str, bytearray))
        Util.is_type(mode, (str, bytes))

        self.__path = path
        self.__mode = mode[0]

        if self.__mode == 'r':
            self.__file = open(self.__path, 'rb')
        elif self.__mode in ('w', 'a'):
            self.__file = open(self.__path, 'rb+')
        else:
            raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})

        fcntl.flock(self.__file, fcntl.LOCK_EX | fcntl.LOCK_NB)

        self.__box = libnacl.secret.SecretBox(secret)
        self.__block_cnt = int(os.stat(
            self.__path).st_size / ConcealIO.TOT_SIZE)
        self.__len = 0 if self.__block_cnt == 0 else self.__length()
        self.__size = self.__block_cnt * ConcealIO.ABLK_SIZE
        self.__block_idx = 0
        self.__cursor = 0
        self.__blk_cursor = 0
        self.__save = False
        self.__buffer = None

        if self.__block_cnt:
            self._load(0)
        else:
            self.__buffer = bytearray(b'\x00' * ConcealIO.ABLK_SIZE)

    def __length(self, offset=None):
        Util.is_type(offset, (int, type(None)))

        realpos = self.__file.tell()
        self.__file.seek(ConcealIO.CBLK_SIZE)

        if offset is None:
            data = self.__box.decrypt(self.__file.read(48))
            offset = struct.unpack('!Q', data)[0]
        elif self.__mode is not 'r':
            data = bytearray(self.__box.encrypt(
                struct.pack('!Q', offset)) + os.urandom(424))
            self.__file.write(data)

        self.__file.seek(realpos)
        return offset

    def _load(self, blk):
        pos = blk * ConcealIO.TOT_SIZE
        res = self.__file.seek(pos)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        if self.__block_cnt >= blk:
            self.__buffer = bytearray(self.__box.decrypt(
                self.__file.read(ConcealIO.CBLK_SIZE)))
        else:
            self.__buffer = bytearray(b'\x00' * ConcealIO.ABLK_SIZE)

        self.__block_idx = blk
        self.__save = False
        return True

    def _save(self):
        if not self.__save:
            return False

        pos = self.__block_idx * ConcealIO.TOT_SIZE
        res = self.__file.seek(pos)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        if self.__block_idx is 0:
            filler = b''
        else:
            filler = os.urandom(472)
        block = bytearray(
            self.__box.encrypt(self.__buffer) + filler)
        self.__file.write(block)  # noqa E501

        if self.__block_idx >= self.__block_cnt:
            self.__blk_cnt = self.__block_idx + 1
            self.__size = self.__block_cnt * ConcealIO.TOT_SIZE

        self.__save = False
        return True

    def close(self):
        if not self.closed:
            self.__length(self.__len)
            fcntl.flock(self.__file, fcntl.LOCK_UN)
            io.RawIOBase.close(self)
            self.__file.close()

    def fileno(self):
        return self.__file.fileno()

    def flush(self):
        self._save()
        self.__length(self.__len)
        io.RawIOBase.flush(self)

    def isatty(self):
        return False

    def read(self, size=-1):
        block = bytearray()
        cursor = 0
        self._save()

        while size > cursor:
            numcpy = min(
                ConcealIO.ABLK_SIZE - self.__blk_cursor, size - cursor)

            block += self.__buffer[self.__blk_cursor:self.__blk_cursor+numcpy]
            cursor += numcpy
            self.__cursor += numcpy
            self.__blk_cursor += numcpy

            if self.__blk_cursor == ConcealIO.ABLK_SIZE:
                self._load(self.__block_idx + 1)
                self.__blk_cursor = 0

        return block

    def readable(self):
        return True

    def readall(self):
        raise NotImplementedError()

    def readinto(self, b):
        raise NotImplementedError()

    def readline(self, size=-1):
        raise NotImplementedError()

    def readlines(self, hint=-1):
        raise NotImplementedError()

    def seek(self, offset, whence=io.SEEK_SET):
        if whence == io.SEEK_SET:
            cursor = min(max(offset, 0), self.__len)
        elif whence == io.SEEK_CUR:
            if offset < 0:
                cursor = max(self.__cursor + offset, 0)
            else:
                cursor = min(self.__cursor + offset, self.__len)
        elif whence == io.SEEK_END:
            cursor = max(min(self.__len + offset, self.__len), 0)
        else:
            raise Util.exception(Error.CONCEAL_INVALID_SEEK, {
                'whence': whence})

        blk = int(math.floor(cursor / self.ABLK_SIZE))
        if self.__block_idx != blk:
            self._save()
            self._load(blk)

        self.__blk_cursor = cursor - (blk * self.ABLK_SIZE)
        self.__cursor = cursor
        return self.__cursor

    def seekable(self):
        return True

    def tell(self):
        return self.__cursor

    def truncate(self, size=None):
        if size:
            blk = int(math.floor(size / self.ABLK_SIZE))
            if self.__block_idx != blk:
                self._save()
                self._load(blk)
            blk_cursor = size - (blk * self.ABLK_SIZE)
            self.__len = size
        else:
            blk_cursor = self.__blk_cursor
            self.__len = self.__cursor

        self.__save = True
        space = ConcealIO.ABLK_SIZE - blk_cursor
        self.__buffer[self.__blk_cursor:ConcealIO.ABLK_SIZE] = b'\x00' * space
        self._save()
        self.__block_cnt = self.__block_idx+1

        self.__length(self.__len)
        self.__file.truncate(self.__block_cnt * ConcealIO.TOT_SIZE)

    def writable(self):
        return True

    def write(self, b):
        Util.is_type(b, (bytes, bytearray, memoryview))

        wrtlen = len(b)
        if not wrtlen:
            return 0

        cursor = 0

        while wrtlen > cursor:
            self.__save = True
            numcpy = min(
                ConcealIO.ABLK_SIZE - self.__blk_cursor, wrtlen - cursor)

            self.__buffer[self.__blk_cursor:self.__blk_cursor + numcpy] = b[cursor: cursor + numcpy]  # noqa E501

            cursor += numcpy
            self.__blk_cursor += numcpy
            self.__cursor += numcpy
            if self.__cursor > self.__len:
                self.__len = self.__cursor
                # self.__length(self.__len)

            if self.__blk_cursor >= ConcealIO.ABLK_SIZE:
                self._save()
                self.__length(self.__len)
                self._load(self.__block_idx + 1)
                self.__blk_cursor = 0

        return cursor if cursor else None

    def writelines(self, lines):
        raise NotImplementedError()

    def __del__(self):
        self.close()

    @property
    def name(self):
        return self.__path
