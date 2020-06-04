# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Data streams operations."""
import hashlib
import struct
import uuid
from abc import ABC, abstractmethod
from collections.abc import Iterator
from io import FileIO, SEEK_END
from typing import Union, Generator

import libnacl.secret
from archive7.base import BLOCK_SIZE

from base import FORMAT_BLOCK, BlockTuple


class StreamIterator(Iterator):
    """Iterate over an Archive7 file."""

    def __init__(self, fileobj: FileIO, generator: Generator = None):
        self._fd = fileobj

        self._fd.seek(0, SEEK_END)
        length = self.__file.tell()

        if length % BLOCK_SIZE:
            raise OSError("Archive length uneven to block size.")

        self._count = length // BLOCK_SIZE
        self._position = 0
        if generator:
            self._generator = generator
        else:
            self._generator = range(self._count)

    @property
    def position(self) -> int:
        """Current position"""
        return self._position

    def __next__(self):
        try:
            self._position = next(self._generator)
            self._fd.seek(self._position * BLOCK_SIZE)
            data = self._fd.read(BLOCK_SIZE)
            return data
        except StopIteration:
            raise StopIteration()


class EncryptorBase(ABC):
    """Encryptor base class."""

    def __init__(self, box):
        self._box = box

    @abstractmethod
    def encrypt(self, data: Union[bytes, bytearray]) -> bytes:
        """Encrypt a piece of data

        Args:
            data (Union[bytes, bytearray]):
                To encrypt

        Returns (bytes):
            Encrypted result

        """
        pass


class DecryptorBase(ABC):
    """Decryptor base class."""

    def __init__(self, box):
        self._box = box

    @abstractmethod
    def decrypt(self, data: Union[bytes, bytearray]) -> bytes:
        """Decrypt a piece of data

        Args:
            data (Union[bytes, bytearray]):
                To decrypt

        Returns (bytes):
            Decrypted result

        """
        pass


class SyncEncryptor(EncryptorBase):
    """Synchronous NaCl encryption."""

    def __init__(self, secret: bytes):
        EncryptorBase.__init__(self, libnacl.secret.SecretBox(secret))

    def encrypt(self, data: Union[bytes, bytearray]) -> bytes:
        """Synchronously encrypt data"""
        return self._box.encrypt(data)


class SyncDecryptor(DecryptorBase):
    """Synchronous NaCl decryption."""

    def __init__(self, secret: bytes):
        DecryptorBase.__init__(self, libnacl.secret.SecretBox(secret))

    def decrypt(self, data: Union[bytes, bytearray]) -> bytes:
        """Synchronously decrypt data"""
        return self._box.decrypt(data)


class AsyncEncryptor(EncryptorBase):
    """Asynchronous NaCl encryption."""

    def __init__(self, secret: bytes, public: bytes):
        EncryptorBase.__init__(self, libnacl.public.Box(secret, public))

    def encrypt(self, data: Union[bytes, bytearray]) -> bytes:
        """Asynchronously encrypt data"""
        return self._box.encrypt(data)


class AsyncDecryptor(DecryptorBase):
    """Asynchronous NaCl decryption."""

    def __init__(self, secret: bytes, public: bytes):
        DecryptorBase.__init__(self, libnacl.public.Box(secret, public))

    def decrypt(self, data: Union[bytes, bytearray]) -> bytes:
        """Asynchronously decrypt data"""
        return self._box.decrypt(data)


class DataFilter(ABC):
    """Abstract data filter class."""

    def __init__(self, config: dict = None):
        self._config = config
        self._data = None

    @property
    def data(self):
        return self._data

    @abstractmethod
    def analyze(self, block: BlockTuple, pos: int):
        """Analyze a block."""
        pass


class CorruptDataFilter(DataFilter):
    """Filter each block for corrupt data."""

    NAME = "corrupt_data"

    def __init__(self):
        DataFilter.__init__(self)
        self._data = set()

    def analyze(self, block: BlockTuple, pos: int):
        """Analyze blocks for data corruption"""
        if hashlib.sha1(block.data).digest() != block.digest:
            self._data.add(pos)
            return True
        else:
            return False


class InvalidMetaFilter(DataFilter):
    """Filter each block and test meta information."""

    NAME = "invalid_meta"

    def __init__(self):
        DataFilter.__init__(self)
        self._data = set()

    def analyze(self, block: BlockTuple, pos: int):
        """Analyze blocks for data corruption"""
        if block.next == pos or block.previous == pos:
            self._data.add(pos)
            return True
        else:
            return False


class StreamIndexerFilter(DataFilter):
    """Filter for indexing all streams."""

    NAME = "stream_indexer"

    def __init__(self):
        DataFilter.__init__(self)
        self._cmp = set()
        self._data = set()

    def analyze(self, block: BlockTuple, pos: int):
        """Analyze blocks for data corruption"""
        if block.stream not in self._cmp:
            self._cmp.add(block.stream)
            self._data.add(uuid.UUID(bytes=block.stream))
            return True
        else:
            return False


class BlockIndexerFilter(DataFilter):
    """Filter for indexing blocks for chosen streams."""

    NAME = "block_indexer"

    def __init__(self):
        DataFilter.__init__(self)
        self._cmp = set()
        self._data = set()

    def analyze(self, block: BlockTuple, pos: int):
        """Analyze blocks for data corruption"""
        if block.stream not in self._cmp:
            self._cmp.add(block.stream)
            self._data.add(uuid.UUID(bytes=block.stream))
            return True
        else:
            return False


class BlockProcessor(ABC):
    """Base class for operations on stream managers, streams and blocks."""
    def __init__(self, fileobj: FileIO, decryptor: DecryptorBase, generator: Generator = None):
        self._fd = fileobj
        self._decryptor = decryptor
        self._filter = self._filters()
        self._generator = generator

    def run(self):
        """Run operation on archive."""
        iterator = StreamIterator(self._fd, self._generator)
        for data in iterator:
            block = BlockTuple(*struct.unpack(FORMAT_BLOCK, self._decryptor.decrypt(data)))
            self.process(
                iterator.position,
                block,
                tuple(f.analyze(block, iterator.position) for f in self._filter)
            )

    @property
    def filter(self):
        """Expose filters."""
        return self._filter

    @abstractmethod
    def _filters(self) -> tuple:
        """Tuple of filters."""
        pass

    @abstractmethod
    def process(self, position: int, block: BlockTuple, result: tuple):
        """Process result of filters."""
        pass


class StreamOperation(ABC):
    pass


class ZipOperation(StreamOperation):
    """Zip streams."""
    pass


class VacuumOperation(StreamOperation):
    """Vacuums an archive and removes the trash."""
    pass


class ReEncryptOperation(StreamOperation):
    """Re-encrypts an archive with a new key."""
    pass


class ShredOperation(ReEncryptOperation):
    """Generates a new key and re-encrypts, then throws the key away."""
    pass
