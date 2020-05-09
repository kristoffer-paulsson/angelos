import copy
import hashlib
import heapq
import logging
import math
import os
import random
import statistics
import struct
import sys
import tracemalloc
from typing import Any
from abc import ABC, abstractmethod
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.ar72 import StreamManager

from libangelos.ar72 import VirtualFileObject


class BaseArchiveTestCase(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.INFO)

        cls.secret = os.urandom(32)

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""

    def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""

        self.dir = TemporaryDirectory()
        self.home = self.dir.name

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.dir.cleanup()


class TestStreamBlock(BaseArchiveTestCase):
    def test_load(self):
        self.fail()


class StreamManagerStub(StreamManager):
    pass


class TestDataStream(BaseArchiveTestCase):
    pass


class TestStreamRegistry(BaseArchiveTestCase):
    def test_load(self):
        self.fail()


class TestStreamManager(BaseArchiveTestCase):
    def test_run(self):
        try:
            data = bytes(os.urandom(2**20))

            mgr = StreamManagerStub(os.path.join(self.home, "test.ar7"), self.secret)
            stream = mgr.new_stream()
            identity = stream.identity

            fileobj = VirtualFileObject(stream, "test", "wb+")
            fileobj.write(data)
            print(fileobj.tell())
            fileobj.close()

            fileobj = VirtualFileObject(mgr.open_stream(identity), "test")
            data2 = fileobj.read()
            print(fileobj.tell())

            self.assertEqual(
                hashlib.sha1(data).digest(),
                hashlib.sha1(data2).digest()
            )
            fileobj.close()
        except Exception as e:
            self.fail(e)
