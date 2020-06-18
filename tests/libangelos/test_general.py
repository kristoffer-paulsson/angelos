import copy
import logging
import os
import random
import sys
import tracemalloc
import uuid
from tempfile import TemporaryDirectory
from unittest import TestCase

from bplustree.serializer import UUIDSerializer
from libangelos.archive7.base import DATA_SIZE

from libangelos.archive7.tree import SimpleBTree
from libangelos.archive7.streams import HollowStreamManager, MultiHollowStreamManager, VirtualFileObject, \
    DynamicMultiStreamManager


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
        self.data = bytearray(os.urandom(2 ** 20))

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.dir.cleanup()


class TestHollowStreamManager(BaseArchiveTestCase):

    def read(self, fileobj, offset, length):
        position = fileobj.seek(offset)
        self.assertEqual(offset, position)
        return fileobj.read(length)

    def write(self, fileobj, offset, length):
        position = fileobj.seek(offset)
        self.assertEqual(offset, position)
        chunk = os.urandom(length)
        fileobj.write(chunk)
        return chunk

    def test_run(self):
        try:
            mgr = HollowStreamManager(os.path.join(self.home, "test.ar7"), self.secret)
            stream = mgr.special_stream(0)
            fileobj = VirtualFileObject(stream, "test", "wb+")
            fileobj.write(self.data)

            for i in range(10000):
                length = random.randrange(2 ** 10, 2 ** 13)
                offset = random.randrange(0, 2 ** 20 - length)

                if random.randrange(2):
                    self.assertEqual(self.data[offset:offset + length], self.read(fileobj, offset, length))
                else:
                    chunk = self.write(fileobj, offset, length)

            fileobj.seek(0)
            data2 = fileobj.read()

            self.assertEqual(bytes(self.data), data2)

            fileobj.close()
            mgr.close()
        except Exception as e:
            self.fail(e)

    def test_run2(self):
        try:
            mgr = MultiHollowStreamManager(os.path.join(self.home, "test.ar7"), self.secret)
            fileobjs = list()
            for s in range(mgr.SPECIAL_STREAM_COUNT):
                fileobjs.append(VirtualFileObject(mgr.special_stream(s), "test", "wb+"))

            for c in range(0, 2 ** 20, DATA_SIZE):
                for f in fileobjs:
                    f.write(self.data[c:c + DATA_SIZE])

            for i in range(10000):
                length = random.randrange(DATA_SIZE // 4, DATA_SIZE * 2)
                offset = random.randrange(0, 2 ** 20 - length)
                fileobj = random.choice(fileobjs)

                if random.randrange(2):
                    self.read(fileobj, offset, length)
                else:
                    self.write(fileobj, offset, length)

            for f in fileobjs:
                f.seek(0)
                f.read()
                f.close()

            mgr.close()
        except Exception as e:
            self.fail(e)

    def test_run3(self):
        try:
            mgr = DynamicMultiStreamManager(os.path.join(self.home, "test.ar7"), self.secret)
            fileobjs = list()
            streams = list()
            for s in range(4):
                stream = mgr.new_stream()
                streams.append(stream)
                fileobjs.append(VirtualFileObject(stream, "test", "wb+"))

            for c in range(0, 2 ** 20, DATA_SIZE):
                for f in fileobjs:
                    f.write(self.data[c:c + DATA_SIZE])

            fileobjs[2].seek(2 ** 19)
            fileobjs[2].truncate()
            identity = streams[3].identity
            streams[3].close()
            mgr.del_stream(identity)

            stream = mgr.new_stream()
            streams.append(stream)
            file4 = VirtualFileObject(stream, "test", "wb+")
            file4.write(self.data)

            objs = fileobjs[:2] + [file4]

            for c in range(0, 2 ** 20, DATA_SIZE):
                for f in objs:
                    f.write(self.data[c:c + DATA_SIZE])

            for i in range(10000):
                length = random.randrange(DATA_SIZE // 4, DATA_SIZE * 2)
                offset = random.randrange(0, 2 ** 20 - length)
                fileobj = random.choice(objs)

                if random.randrange(2):
                    self.read(fileobj, offset, length)
                else:
                    self.write(fileobj, offset, length)

            for f in objs:
                f.seek(0)
                f.read()
                f.close()

            # self.assertEqual(objs[0].read(), self.data)
            # self.assertEqual(objs[1].read(), self.data)
            # self.assertEqual(objs[2].read(), self.data)

            mgr.close()
        except Exception as e:
            self.fail(e)


class TestBPlusTree(TestCase):
    def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""

        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.key_size = 16
        self.value_size = 32

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.dir.cleanup()

    def test_run(self):
        try:
            bank = set()
            tree = SingleItemTree(
                open(os.path.join(self.home, "database.db"), "wb+"),
                open(os.path.join(self.home, "journal.db"), "wb+"),
                page_size=1024,
                key_size=self.key_size,
                value_size=self.value_size,
                cache_size=64,
                serializer=UUIDSerializer()
            )
            for i in range(100000):
                print(i)
                key = os.urandom(self.key_size)
                value = os.urandom(self.value_size)
                tree.insert(uuid.UUID(bytes=key), value)
                tree.checkpoint()
                bank.add(key)

            tree.close()

        except Exception as e:
            self.fail(e)

    def test_fuzz(self):
        iteration = None
        try:
            bank = set()
            tree = SimpleBTree(
                open(os.path.join(self.home, "database.db"), "wb+"),
                order=128,
                key_size=self.key_size,
                value_size=self.value_size,
            )

            for iteration in range(20000):

                if len(bank) < 10000:
                    key = uuid.UUID(bytes=os.urandom(self.key_size))
                    print("Insert", key)
                    value = os.urandom(self.value_size)
                    tree.insert(key, value)
                    bank.add(key)
                    continue

                key = random.choice(list(bank))
                op = random.randrange(3)

                if op == 0:
                    print("Access", key)
                    tree.get(key)
                elif op == 1:
                    print("Update", key)
                    tree.update(key, os.urandom(self.value_size))
                elif op == 2:
                    print("Delete", key)
                    tree.delete(key)
                    bank.remove(key)

            for i in bank:
                tree.delete(i)

            tree.close()
            print(os.stat(os.path.join(self.home, "database.db")).st_size)

        except Exception as e:
            print(iteration)
            self.fail(e)
