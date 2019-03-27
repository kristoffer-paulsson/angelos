import io
import os
import fcntl
import struct
import math
import array
import libnacl

from ..utils import Util
from ..error import Error


class ConcealIO(io.RawIOBase):
    TOT_SIZE = 512*33
    CBLK_SIZE = 512*32 + 40
    ABLK_SIZE = 512*32

    def __init__(self, file, mode='rb', secret=None):
        Util.is_type(file, (str, bytes, io.IOBase))
        Util.is_type(mode, (str, bytes))
        Util.is_type(secret, (str, bytes))

        if isinstance(file, io.IOBase):
            if file.mode not in ['rb', 'rb+', 'wb', 'ab']:
                raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
            self.__path = file.name
            self.__mode = file.mode
            self.__file = file
            self.__do_close = False
        else:
            if mode not in ['rb', 'rb+', 'wb', 'ab']:
                raise Util.exception(Error.CONCEAL_UNKOWN_MODE, {'mode', mode})
            self.__path = file
            self.__mode = mode
            self.__file = open(file, mode)
            self.__do_close = True

        fcntl.flock(self.__file, fcntl.LOCK_EX | fcntl.LOCK_NB)

        self.__box = libnacl.secret.SecretBox(secret)
        self.__block_cnt = int(os.fstat(
            self.__file.fileno()).st_size / ConcealIO.TOT_SIZE)
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
            self.__buffer = bytearray().ljust(ConcealIO.ABLK_SIZE, b'\x00')

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    def __length(self, offset=None):
        Util.is_type(offset, (int, type(None)))

        realpos = self.__file.tell()
        self.__file.seek(ConcealIO.CBLK_SIZE)

        if offset is None:
            data = self.__box.decrypt(self.__file.read(48))
            offset = struct.unpack('!Q', data)[0]
        elif self.__mode in ['rb+', 'wb']:
            data = bytearray(self.__box.encrypt(
                struct.pack('!Q', offset)) + os.urandom(424))
            self.__file.write(data)

        self.__file.seek(realpos)
        return offset

    def _load(self, blk):
        pos = blk * ConcealIO.TOT_SIZE
        res = self.__file.seek(pos)
        print('Load block:', blk)

        if pos != res:
            raise Util.exception(Error.CONCEAL_POSITION_ERROR, {
                'position': pos, 'result': res})

        if self.__block_cnt > blk:
            self.__buffer = bytearray(self.__box.decrypt(
                self.__file.read(ConcealIO.CBLK_SIZE)))
        else:
            self.__buffer = bytearray().ljust(ConcealIO.ABLK_SIZE, b'\x00')

        self.__block_idx = blk
        self.__save = False
        return True

    def _save(self):
        if not self.__save:
            return False

        pos = self.__block_idx * ConcealIO.TOT_SIZE
        print('Save block:', self.__block_idx)
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
        self.__file.write(block)

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
            if self.__do_close:
                self.__file.close()

    def fileno(self):
        return self.__file.fileno()

    def flush(self):
        self._save()
        self.__length(self.__len)
        io.RawIOBase.flush(self)

    def isatty(self):
        if self.closed:
            raise ValueError()
        return False

    def read(self, size=-1):
        if self.closed:
            raise ValueError()

        if isinstance(size, type(None)) or size == -1:
            size = self.__len - self.__cursor
        if size > (self.__len - self.__cursor):
            raise ValueError()

        block = bytearray()
        cursor = 0
        self._save()

        print('Read:', self.__cursor, size)

        while size > cursor:
            numcpy = min(
                ConcealIO.ABLK_SIZE - self.__blk_cursor, size - cursor)

            block += self.__buffer[self.__blk_cursor:self.__blk_cursor+numcpy]
            print('Buffer read:', self.__cursor, numcpy)
            cursor += numcpy
            self.__cursor += numcpy
            self.__blk_cursor += numcpy

            if self.__blk_cursor == ConcealIO.ABLK_SIZE:
                self._load(self.__block_idx + 1)
                self.__blk_cursor = 0

        return block

    def readable(self):
        if self.closed:
            raise ValueError()
        return True

    def readall(self):
        if self.closed:
            raise ValueError()
        return self.read()

    def readinto(self, b):
        if self.closed:
            raise ValueError()
        Util.is_type(b, (bytearray, memoryview, array.array))
        size = min(len(b), self.__len - self.__cursor)
        if isinstance(b, memoryview):
            b.cast('b')
        # for k, v in enumerate(self.read(size)):
        b[:size] = array.array('', self.read(size)[:size])
        if isinstance(b, memoryview):
            b.cast(b.format)
        return size

    def readline(self, size=-1):
        if self.closed:
            raise ValueError()

    def readlines(self, hint=-1):
        if self.closed:
            raise ValueError()

    def seek(self, offset, whence=io.SEEK_SET):
        if self.closed:
            raise ValueError()
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
        if self.closed:
            raise ValueError()
        return True

    def tell(self):
        if self.closed:
            raise ValueError()
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
        if self.closed:
            raise ValueError()
        return True

    def write(self, b):
        if self.closed:
            raise ValueError()

        Util.is_type(b, (bytes, bytearray, memoryview))

        wrtlen = len(b)
        if not wrtlen:
            return 0

        cursor = 0

        print('Write:', self.__cursor, wrtlen)

        while wrtlen > cursor:
            self.__save = True
            numcpy = min(
                ConcealIO.ABLK_SIZE - self.__blk_cursor, wrtlen - cursor)

            self.__buffer[self.__blk_cursor:self.__blk_cursor + numcpy] = b[cursor: cursor + numcpy]  # noqa E501
            print('Buffer write:', self.__cursor, numcpy)

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
        if self.closed:
            raise ValueError()

        for line in lines:
            if not isinstance(line, bytes):
                raise TypeError()
            self.write(line)

    # def __del__(self):
    #    self.close()

    @property
    def name(self):
        return self.__path

    @property
    def mode(self):
        return self.__mode
