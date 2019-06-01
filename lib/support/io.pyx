# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""


cdef class IOBase:  # (metaclass=abc.ABCMeta)
    cdef seek(self, pos, whence=0):
        pass

    cdef tell(self):
        return self.seek(0, 1)

    cdef truncate(self, pos=None):
        pass

    cdef flush(self):
        self._checkClosed()

    __closed = False

    cdef close(self):
        if not self.__closed:
            try:
                self.flush()
            finally:
                self.__closed = True

    cdef __del__(self):
        try:
            self.close()
        except:
            pass

    cdef seekable(self):
        """File or stream is not seekable."""
        return False

    cpdef readable(self):
        """File or stream is not readable."""
        return False

    cpdef writable(self):
        """"File or stream is not writable.""""
        return False

    @property
    cdef closed(self):
        return self.__closed

    cdef _checkClosed(self, msg=None):
        if self.closed:
            raise ValueError("I/O operation on closed file."
                             if msg is None else msg)

    cdef __enter__(self):
        self._checkClosed()
        return self

    cdef __exit__(self, *args):
        self.close()

    cdef fileno(self):
        pass

    cdef isatty(self):
        self._checkClosed()
        return False

    cdef readline(self, size=-1):
        if hasattr(self, "peek"):
            def nreadahead():
                readahead = self.peek(1)
                if not readahead:
                    return 1
                n = (readahead.find(b"\n") + 1) or len(readahead)
                if size >= 0:
                    n = min(n, size)
                return n
        else:
            def nreadahead():
                return 1
        if size is None:
            size = -1
        else:
            try:
                size_index = size.__index__
            except AttributeError:
                raise TypeError(f"{size!r} is not an integer")
            else:
                size = size_index()
        res = bytearray()
        while size < 0 or len(res) < size:
            b = self.read(nreadahead())
            if not b:
                break
            res += b
            if res.endswith(b"\n"):
                break
        return bytes(res)

    cdef __iter__(self):
        self._checkClosed()
        return self

    cdef __next__(self):
        line = self.readline()
        if not line:
            raise StopIteration
        return line

    cdef readlines(self, hint=None):
        if hint is None or hint <= 0:
            return list(self)
        n = 0
        lines = []
        for line in self:
            lines.append(line)
            n += len(line)
            if n >= hint:
                break
        return lines

    cdef writelines(self, lines):
        self._checkClosed()
        for line in lines:
            self.write(line)


cdef class RawIOBase(IOBase):
    cdef read(self, size=-1):
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

    cdef readall(self):
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

    cdef readinto(self, b):
        pass

    cdef write(self, b):
        pass
