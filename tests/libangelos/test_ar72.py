import copy
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


class HeapRecord(ABC):
    """Record used in a heap list to be sorted in the heap."""

    def __init__(self):
        self._hash = self._digest()

    def update(self):
        """Update the digest when recorded values change."""
        self._hash = self._digest()

    @abstractmethod
    def _digest(self):
        """Calculate the digest to be used for comparison."""
        pass

    def __hash__(self):
        """Use the digest as hash for comparison."""
        return self._hash


class HeapList:
    """List-like object that can sync records to a data-stream via a file-like object.

    The heap swap operation is recorded in a journal for data recovery.
    """

    def swap(self, x: int, y: int):
        """Do a heap swap operation with recovery support."""
        pass  # FIXME: Implement!

    def recover(self) -> bool:
        """Look for failed swap in the journal and complete swap."""
        pass  # FIXME: Implement!


class Heap2:
    """Heap class that uses a flattened list for its B-Tree.

    If 'index' is the index of the parent node,
    then '2 * index' is the index of the left child node,
    and '2 * index + 1' is the index of the right child node.

    If 'index' is the index of a child node,
    then 'index // 2' is the index of the parent node.
    The parent node is rounded down towards the least integer,
    therefore the index could be either left or right binary child index.

    """

    def __init__(self, heap: list = []):
        self.__heap = [0] + heap

    @property
    def heap(self):
        return self.__heap

    def __len__(self):
        return len(self.__heap) - 1

    def insert(self, record):
        """Insert a new record at the end of the heap.

        Args:
            record:
                The record to be stored on the heap.

        """
        self.__heap.append(record)  # Insert at the far end
        self.bubble()

    def bubble(self):
        """Move a child node up in the tree structure, lets child nodes bubble up the structure if easier.

        By iterating from the end of the heap to the beginning with steps according to binary tree length,
        comparing the child node value with the parent value. If child is less than parent, then swap place
        of the nodes.
        """
        index = len(self)
        while index // 2 > 0:  # While 'parent' is greater than zero (within bounds)
            if self.__heap[index] < self.__heap[index // 2]:  # If 'child' is less than 'parent'
                self.swap(index, index // 2)  # (then) swap place on 'child' and 'parent'
            index = index // 2

    def sink(self, index: int):
        """Move a child/parent down in the tree structure, lets parent nodes sink down the structure if heavier.

        By iterating from the index to the end with steps according to binary tree length, comparing the
        children for the lesser value then compare the parent and the least child. If the parent is
        greater than the child, then swap place of the nodes.

        Args:
            index (int):
                Starting position.

        """
        length = len(self)
        while 2 * index <= length:  # While 'left' child is within bounds
            min_index = self.compare(index)  # Get the lesser child index
            if self.__heap[index] > self.__heap[min_index]:  # If 'parent' is greater than 'child'
                self.swap(index, min_index)  # (then) swap place on 'parent' and 'child'
            index = min_index  # Make 'child' the new 'parent', walk downwards.

    def compare(self, index: int) -> int:
        """Compare two children of a parent node, return index of the lesser one.

        First, if the right child node is out of bounds, return left child node index.
        Second, compare left and right child and return the index of the smaller one.

        Args:
            index (int):
                Index of parent node.

        Returns (int):
            Index of the child of lesser value.

        """
        if 2 * index + 1 > len(self):  # if 'right' index is out of bounds
            return 2 * index  # (then) Return 'left' index
        if self.__heap[2 * index] < self.__heap[2 * index + 1]:  # If 'left' is less than 'right'
            return 2 * index  # (then) Return 'left' index
        return 2 * index + 1  # (else) return 'right' index

    def heapify(self):
        """Heapify the heap list.

        First find the parent node of the whole heap, then iterate towards the beginning
        stepping one step at a time, swapping greater nodes down the tree structure
        iteratively with steps according to binary tree length
        """
        index = len(self) // 2
        while index > 0:
            self.sink(index)
            index -= 1

    def sort(self):
        """Like heapify but faster."""
        pass  # TODO: Find good algorithm and implement

    def swap(self, first: int, second: int):
        """Swapping place of two nodes based on first and second index.

        Args:
            first (int):
                Index of first node.
            second (int):
                Index of second node.

        """
        print("Swap:", first, second)
        temporary = self.__heap[first]
        self.__heap[first] = self.__heap[second]
        self.__heap[second] = temporary

    def extract(self, index: int = 1) -> Any:
        """Detach record at index.

        Defaults to first node to get smallest value.


        Args:
            index (int):
                Index of record to detach.

        Returns (Any):
            Record to remove from heap.

        """
        if len(self) == index:
            raise IndexError("Index out of bounds, %s" % index)
        record = self.__heap[index]
        self.__heap[index] = self.__heap[len(self.__heap)]
        self.__heap.pop()
        self.sink(index)
        return record

    def search(self, record):
        """Search for a record based on a hash value.

        Args:
            record:
                Record hash value.

        Returns:
            The found record index or 0

        """
        length = len(self)
        index = 1  # Set start index at root parent node

        while 2 * index <= length:  # While 'left' child is within bounds
            if self.__heap[index] == record:  # Compare index node hash with search hash
                return index  # If record hash matches return index.

            left = 2 * index  # Left child index
            right = left if left + 1 > length else left + 1  # Right child index (within bounds correction)

            if self.__heap[left] > record:  # If left child is greater or equal to record
                print("Left", left, self.__heap[left])
                index = left  # Traverse down the left child node
                continue
            elif self.__heap[right] < record:  # If right child is less or equal to record
                print("Right", right, self.__heap[right])
                index = right  # Traverse down the right child node
                continue

        return 0

    def search2(self, key):
        current_node = 1
        while 2 * current_node < len(self.__heap):
            if key == self.__heap[current_node]:
                print("Index:", current_node)
                return current_node
            if key > self.__heap[2 * current_node]:
                print("Left:", current_node)
                current_node = 2 * current_node
            elif 2 * current_node + 1 < len(self.__heap):  # key > current_node.key:
                current_node = 2 * current_node + 1
        return current_node

    def test(self, subtract=0):
        index = len(self.__heap) - 1 - subtract
        while index > 0:
            print(self.__heap[index])
            index = index // 2


class Heap3:
    def __init__(self, heap: list = []):
        self.__heap = heap

    @property
    def heap(self):
        return self.__heap

    def swap(self, first: int, second: int):
        print("Swap:", first, second)
        temporary = self.__heap[first]
        self.__heap[first] = self.__heap[second]
        self.__heap[second] = temporary

    def build(self):
        for i in range(len(self.__heap)):
            print("Iteration", i)
            # if child is bigger than parent
            if self.__heap[i] > self.__heap[int((i - 1) / 2)]:
                j = i

                # swap child and parent until
                # parent is smaller
                while self.__heap[j] > self.__heap[int((j - 1) / 2)]:
                    self.swap(j, int((j - 1) / 2))
                    j = int((j - 1) / 2)

    def update(self, start):
        i = start

        if self.__heap[i] > self.__heap[int((i - 1) / 2)]:
            j = i

            # swap child and parent until
            # parent is smaller
            while self.__heap[j] > self.__heap[int((j - 1) / 2)]:
                self.swap(j, int((j - 1) / 2))
                j = int((j - 1) / 2)


class Splay:
    def __init__(self):
        self.__heap = []
        self.__size = 0

    def parent(self, index: int) -> int:
        return (index - 1) // 2

    def left(self, index: int) -> int:
        idx = 2 * index + 1
        return idx if idx < self.__size else None

    def right(self, index: int) -> int:
        idx = 2 * index + 2
        return idx if idx < self.__size else None

    def __left_rotate(self, index: int):
        right = self.right(index)

        if right:
            self.__heap[self.right(index)] = self.__heap[self.left(right)]
            if self.left(right):
                self.__heap[self.parent(self.left(right))] = self.__heap[index]
            self.__heap[self.parent(right)] = self.__heap[self.parent(index)]

        if not self.parent(index):
            self.__heap[0] = self.__heap[right]
        elif index == self.left(self.parent(index)):
            self.__heap[self.left(self.parent(index))] = self.__heap[right]
        else:
            self.__heap[self.right(self.parent(index))] = self.__heap[right]

        if right:
            self.__heap[self.left(right)] = self.__heap[index]
        self.__heap[self.parent(index)] = self.__heap[right]

    def __right_rotate(self, index: int):
        left = self.right(index)

        if left:
            self.__heap[self.left(index)] = self.__heap[self.right(left)]
            if self.right(left):
                self.__heap[self.parent(self.right(left))] = self.__heap[index]
            self.__heap[self.parent(left)] = self.__heap[self.parent(index)]

        if not self.parent(index):
            self.__heap[0] = self.__heap[left]
        elif index == self.left(self.parent(index)):
            self.__heap[self.left(self.parent(index))] = self.__heap[left]
        else:
            self.__heap[self.right(self.parent(index))] = self.__heap[left]

        if left:
            self.__heap[self.right(left)] = self.__heap[index]
        self.__heap[self.parent(index)] = self.__heap[left]

    def __splay(self, index: int):
        while self.parent(index):
            if not self.parent(self.parent(index)):
                if self.left(self.parent(index)) == index:
                    self.__right_rotate(self.parent(index))
                else:
                    self.__left_rotate(self.parent(index))
            elif self.left(self.parent(index)) == index and self.left(self.parent(self.parent(index))) == self.parent(index):
                self.__right_rotate(self.parent(self.parent(index)))
                self.__right_rotate(self.parent(index))
            elif self.right(self.parent(index)) == index and self.right(self.parent(self.parent(index))) == self.parent(index):
                self.__left_rotate(self.parent(self.parent(index)))
                self.__left_rotate(self.parent(index))
            elif self.left(self.parent(index)) == index and self.right(self.parent(self.parent(index))) == self.parent(index):
                self.__right_rotate(self.parent(self.parent(index)))
                self.__left_rotate(self.parent(index))
            else:
                self.__left_rotate(self.parent(index))
                self.__right_rotate(self.parent(index))


class HeapRecord(ABC):
    FORMAT = ""

    def __init__(self, *largs, **kwargs):
        if largs and not kwargs:
            self._unpack(largs, kwargs)

        for name in kwargs.keys():
            setattr(self, name, kwargs.get(name))

    @abstractmethod
    def keys(self) -> bytes:
        """Calculate index key."""
        pass

    @abstractmethod
    def _pack(self) -> tuple:
        pass

    @abstractmethod
    def _unpack(self, info: tuple, insert: dict):
        pass

    def dumps(self) -> bytes:
        return struct.pack(self.FORMAT, *self._pack())
        # self.previous, self.next, self.index, self.stream, hashlib.sha1(self.data).digest(), self.data

    @classmethod
    def loads(cls, data: bytes) -> HeapRecord:
        return cls(*struct.unpack(cls.FORMAT, data))

    def __eq__(self, other):
        """Compare two records by type and hash.

        Args:
            other (HeapRecord):
                Should be a record of same type.

        Returns (bool):
            True or False based on hash comparison.

        """
        if not isinstance(other, type(self)):
            raise TypeError("Records of different types.")
        else:
            return self.__hash__() == other.__hash__()

    def __hash__(self):
        """Hashing record searchable key."""
        return hash(self.keys())


class AvarageHeap:
    """Avarege Search Binary Heap.

    https://github.com/willemt/array-avl-tree/blob/master/avl_tree.c
    """

    def __init__(self):
        self.__heap = [None for _ in range(100)]
        self.__length = len(self.__heap)
        self.__cnt = 0

    @property
    def heap(self):
        return self.__heap

    def __len__(self):
        return self.__length

    def __left(self, index: int):
        return 2 * index + 1

    def __right(self, index: int):
        return 2 * index + 2

    def __parent(self, index):
        return None if index <= 0 else (index - 1) // 2

    def __enlarge(self):
        """Use this function to reserve space for array."""
        self.__heap += [None for _ in range(100)]
        self.__length = len(self.__heap)

    def __count(self, index: int) -> int:
        if self.__length <= index or not self.__heap[index]:  # .key:
            return 0
        return self.__count(self.__left(index)) + self.__count(self.__right(index)) + 1

    def count(self) -> int:
        return self.__cnt

    def __height(self, index: int) -> int:
        if index >= self.__length or not self.__heap[index]:  # .key:
            return 0
        return max(self.__height(self.__left(index)) + 1, self.__height(self.__right(index)) + 1)

    def height(self) -> int:
        return self.__height(0)

    def __bubble(self, index: int, towards: int):
        if not self.__heap[index]:  # .key:
            return

        self.__heap[towards] = self.__heap[index]
        self.__heap[index] = None
        self.__bubble(self.__left(index), self.__left(towards))
        self.__bubble(self.__right(index), self.__right(towards))

    def __sink(self, index: int, towards: int):
        if not self.__heap[index] or index >= self.__length:  # .key:
            return

        self.__heap[index] = 0  # None
        self.__sink(self.__left(index), self.__left(towards))
        self.__sink(self.__right(index), self.__right(towards))
        self.__heap[towards] = self.__heap[index]

    def __rotate_right(self, index: int):
        self.__sink(self.__right(index), self.__right(self.__right(index)))
        self.__heap[self.__right(index)] = self.__heap[index]

        self.__sink(self.__right(self.__left(index)), self.__left(self.__right(index)))
        self.__heap[self.__right(self.__left(index))] = None  # .key:

        self.__bubble(self.__left(index), index)

    def seek(self, key: int) -> int:
        index = 0

        while index < self.__length:
            node = self.__heap[index]

            if not node:  # .key:
                return None

            result = key - node  # Compare function goes here

            if result == 0:
                return index
            elif result < 0:
                index = self.__left(index)
            elif result > 0:
                index = self.__right(index)
            else:
                raise IndexError()

        return None

    def get(self, index: int) -> int:
        return self.__heap[index]

    def __rotate_left(self, index: int):
        parent = self.__parent(index)

        self.___sink(self.__left(parent), self.__left(self.__left(parent)))
        self.__heap[self.__left(parent)] = self.__heap[parent]

        self.__sink(self.__left(index), self.__right(self.__left(parent)))
        self.__heap[self.__left(index)] = None

        self.__bubble(index, parent)

    def __rebalance(self, index: int):
        while True:
            if abs(self.__height(self.__left(index)) - self.__height(self.__right(index))):
                if -1 == self.__height(self.__left(self.__right(index))) - self.__height(self.__right(self.__right(index))):
                    self.__rotate_left(self.__right(index))
                else:
                    self.__rotate_left(self.__right(index))
                    self.__rotate_right(self.__right(index))

            if not index:
                break
            index = self.__parent(index)

    def __previous_ordered_node(self, index: int) -> int:
        previous = -1
        index = self.__left(index)

        while index < self.__length and self.__heap[index]:
            previous = index
            index = self.__right(index)

        return previous

    def remove(self, key: int) -> int:
        index = 0
        while index < self.__length:
            node = self.__heap[index]

            if not node:  # .key:
                return None

            result = key - node  # Compare function goes here
            if result == 0:
                self.__cnt -= 1
                rep = self.__previous_ordered_node(index)

                if -1 == rep:
                    self.__heap[index] = None
                else:
                    self.__bubble(self.__left(rep), self.__right(self.__parent(rep)))
                    self.__bubble(rep, index)

                if index:
                    self.__rebalance(self.__parent(index))
                return index
            elif result < 0:
                index = self.__left(index)
            elif result > 0:
                index = self.__right(index)
            else:
                raise IndexError()

        return None

    def empty(self):
        index = 0
        while index < self.__length:
            self.__heap[index] = None
            index += 1

    def insert(self, key: int) -> int:
        index = 0
        while index < self.__length:
            node = self.__heap[index]

            if not node:
                self.__heap[index] = key
                self.__cnt += 1

                if not index:
                    return
                self.__rebalance(self.__parent(index))
                return

            result = key - node  # Compare function goes here
            if result == 0:
                self.__heap[index] = key
                return
            elif result < 0:
                index = self.__left(index)
            elif result > 0:
                index = self.__right(index)
            else:
                raise IndexError()

        self.__enlarge()
        self.__heap[index] = key
        self.__cnt += 1


class TestHeapRecord(HeapRecord):
    FORMAT = "!Q"

    def keys(self) -> bytes:
        bytes(self.value)

    def _pack(self) -> tuple:
        pass

    def _unpack(self, info: tuple, insert: dict):
        pass


class TestAvarageHeap(TestCase):
    REF_LIST = [94, 54, 19, 74, 99, 24, 79, 34, 14, 39, 69, 64, 9, 49, 89, 4, 84, 29, 44, 59]
    REF_HEAP_MAX = [99, 94, 89, 84, 69, 64, 79, 74, 44, 59, 54, 24, 9, 49, 19, 4, 34, 29, 14, 39]
    REF_HEAP_MIN = [4, 14, 9, 29, 39, 19, 49, 34, 44, 59, 69, 64, 24, 79, 89, 74, 84, 54, 94, 99]

    def setUp(self) -> None:
        heap = list(range(4, 100, 5))
        self.rand_list = copy.deepcopy(heap)
        random.shuffle(self.rand_list)
        self.heap_list = copy.deepcopy(heap)
        heapq.heapify(self.heap_list)

    def list(self, power: int = 5, odd: bool = False):
        lr = list(range(1 if odd else 0, 2 ** power))
        return lr, lr[0], lr[-1]

    def test_run(self):
        heap = AvarageHeap()
        for data in self.REF_LIST:
            heap.insert(TestHeapRecord(value=data))

    def test_traverse(self):
        try:
            hc1, _, _ = self.list(5, True)
            hc2, _, _ = self.list(5, True)
            hc3, _, _ = self.list(5, True)
            random.shuffle(hc2)
            random.shuffle(hc3)

            heap1 = AvarageHeap(hc1)
            heap1.build2()
            print(heap1.heap)

            heap2 = AvarageHeap(hc2)
            heap2.build2()
            print(heap2.heap)

            heap3 = AvarageHeap(hc3)
            heap3.build2()
            print(heap3.heap)

        except Exception as e:
            self.fail(e)

    def test_build(self):
        try:
            hc, minv, maxv = self.list(5, True)
            heap = AvarageHeap(copy.deepcopy(hc))
            heap.build()
            print(heap.heap)
            self.assertEqual(minv, heap.min())
            self.assertEqual(maxv, heap.max())

            hc, minv, maxv = self.list(s)
            heap = AvarageHeap(copy.deepcopy(hc))
            heap.build()
            print(heap.heap)
            self.assertEqual(minv, heap.min())
            self.assertEqual(maxv, heap.max())

            heap = AvarageHeap(copy.deepcopy(self.REF_LIST))
            heap.build()
            print(heap.heap)
            self.assertEqual(max(self.REF_LIST), heap.min())
            self.assertEqual(min(self.REF_LIST), heap.max())
        except Exception as e:
            self.fail(e)

    def test_search(self):
        try:
            hc, minv, maxv = self.list(9, True)
            heap = AvarageHeap(copy.deepcopy(hc))
            heap.build()
            print(heap.heap)
            term = 345
            result = heap.search(term)
            if result is not None:
                print("Search: term(%s), index(%s), result(%s)" % (term, result, heap.heap[result]))
            else:
                print("Result:", result)
        except Exception as e:
            self.fail(e)

    def test_insert(self):
        try:
            hc, _, _ = self.list(5, True)
            # random.shuffle(hc)

            heap = AvarageHeap()
            for i in hc:
                heap.insert(i)

            print(heap.heap)
        except Exception as e:
            self.fail(e)


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
        heap.insert(2)
        heap.insert(4)

        heap.insert(6)
        heap.insert(8)
        heap.insert(10)
        heap.insert(12)
        print("Display heap after insertion:")
        heap.display_heap()
        print("root of the heap", heap.get_min(), "\n")
        heap.delete(2)
        print("Heap after delete_key(2):")
        heap.display_heap()
        print("minimum element on the heap", heap.extract(), "\n")
        heap.decrease(1, 1)
        print("new root of the heap after decrease_key(1, 1)", heap.get_min(), "\n")
