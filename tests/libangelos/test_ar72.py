import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.ar72 import StreamManager


class MinHeap:
    def __init__(self, capacity: int = 0):
        self.__heap = [int(0) for _ in range(capacity)]  # Elements in heap
        self.__capacity = capacity  # Maximum capacity of heap
        self.__heap_size = 0  # Current heap size

    def __swap(self, x: int, y: int):
        """Swap two elements."""
        temp = self.__heap[x]
        self.__heap[x] = self.__heap[y]
        self.__heap[y] = temp

    def heapify(self, i: int):
        """To heapify a subtree with the root at given index."""
        l = self.left(i)
        r = self.right(i)
        min = i
        if l < self.__heap_size and self.__heap[l] < self.__heap[i]:
            min = l
        if r < self.__heap_size and self.__heap[r] < self.__heap[min]:
            min = r
        if min != i:
            self.__swap(i, min)
            self.heapify(min)

    def parent(self, i: int) -> int:
        return int((i - 1) / 2)

    def left(self, i: int) -> int:
        """Left child of node i."""
        return 2 * i + 1

    def right(self, i: int) -> int:
        """Right child of node i."""
        return 2 * i + 2

    def extract_min(self) -> int:
        """Extract minimum element in the heap(root of the heap)"""
        if self.__heap_size <= 0:
            return 2**64
        if self.__heap_size == 1:
            self.__heap_size -= 1
            return self.__heap[0]

        root = self.__heap[0]
        self.__heap[0] = self.__heap[self.__heap_size - 1]
        self.__heap_size -= 1
        self.heapify(0)

        return root

    def decrease_key(self, i: int, new_key: int):
        """Decrease key value to newKey at i."""
        self.__heap[i] = new_key
        while not i and self.__heap[self.parent(i)] > self.__heap[i]:
            self.__swap(i, self.__parent(i))
            i = self.parent(i)

    def get_min(self) -> int:
        """Returns root of the min heap."""
        return self.__heap[0]

    def delete_key(self, i: int):
        """Deletes a key at i."""
        self.decrease_key(i, -1*2**64)
        self.extract_min()

    def insert_key(self, key: int):
        try:
            if self.__heap_size == self.__capacity:
                raise OverflowError("Could not insert key")
        except OverflowError as e:
            print(e)
            return

        self.__heap_size += 1
        i = self.__heap_size - 1
        self.__heap[i] = key

        print(i)
        while not i and self.__heap[self.parent(i)] > self.__heap_size[i]:
            self.__swap(i, self.parent(i))
            i = self.parent(i)

    def display_heap(self):
        for i in range(self.__heap_size):
            print(self.__heap[i], " ")
        print("\n")


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
            mgr = StreamManagerStub(os.path.join(self.home, "test.ar7"), self.secret)
        except Exception as e:
            self.fail(e)

    def test_heap(self):
        heap = MinHeap(11)
        heap.insert_key(2)
        heap.insert_key(4)

        heap.insert_key(6)
        heap.insert_key(8)
        heap.insert_key(10)
        heap.insert_key(12)
        print("Display heap after insertion:")
        heap.display_heap()
        print("root of the heap", heap.get_min(), "\n")
        heap.delete_key(2)
        print("Heap after delete_key(2):")
        heap.display_heap()
        print("minimum element on the heap", heap.extract_min(), "\n")
        heap.decrease_key(1, 1)
        print("new root of the heap after decrease_key(1, 1)", heap.get_min(), "\n")
