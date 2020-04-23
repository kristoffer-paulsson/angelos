"""
Learn and write a heap tree.
"""
from typing import Any


class MinHeap:
    def __init__(self):
        self.items = [0]

    def __len__(self):
        return len(self.items) - 1

    def insert(self, x):
        self.items.append(x)
        self.up()

    def up(self):
        i = len(self)
        while i // 2 > 0:
            if self.items[i] < self.items[i // 2]:
                self.items[i], self.items[i // 2] = self.items[i // 2], self.items[i]
            i = i // 2

    def extract_Min(self):
        if len(self) == 1:
            return str('cannot extract_Min no elements present')
        value = self.items[1]
        self.items[1] = self.items[len(self)]
        self.items.pop()
        self.down(1)
        return value

    def down(self, i):
        while 2 * i <= len(self):
            mi = self.minimum(i)
            if self.items[i] > self.items[mi]:
                self.items[i], self.items[mi] = self.items[mi], self.items[i]
            i = mi

    def minimum(self, i):
        if 2 * i + 1 > len(self):
            return 2 * i
        if self.items[2 * i] < self.items[2 * i + 1]:
            return 2 * i
        return 2 * i + 1

    def build_heap(self, li):
        i = len(li) // 2
        self.items = [0] + li
        while i > 0:
            self.down(i)
            i = i - 1

    def prin(self):
        res = []
        for i in range(1, len(self.items)):
            res.append(self.items[i])
        return res

    def heapify(self):
        i = len(self) // 2
        while i > 0:
            self.down(i)
            i = i - 1


class MaxHeap:
    def __init__(self):
        self.items = [0]

    def __len__(self):
        return len(self.items) - 1

    def insert(self, val):
        self.items.append(val)
        self.up()

    def up(self):
        i = len(self)
        while i // 2 > 0:
            if self.items[i] > self.items[i // 2]:
                self.items[i], self.items[i // 2] = self.items[i // 2], self.items[i]
            i = i // 2

    def extract_Max(self):
        if len(self) == 1:
            return str('cannot extract_Max no elements present')
        value = self.items[1]
        self.items[1] = self.items[len(self)]
        self.items.pop()
        self.down(1)
        return value

    def down(self, i):
        while 2 * i <= len(self):
            mc = self.maximum(i)
            if self.items[i] < self.items[mc]:
                self.items[i], self.items[mc] = self.items[mc], self.items[i]
            i = mc

    def maximum(self, i):
        if 2 * i + 1 > len(self):
            return 2 * i
        if self.items[2 * i] > self.items[2 * i + 1]:
            return 2 * i
        return 2 * i + 1

    def build_heap(self, alist):
        i = len(alist) // 2
        self.items = [0] + alist
        while i > 0:
            self.down(i)
            i = i - 1

    def prin(self):
        res = []
        for i in range(1, (len(self.items))):
            res.append(self.items[i])
        return res

    def heapify(self):
        i = len(self) // 2
        while i > 0:
            self.down(i)
            i = i - 1


class testHeap:
    def __init__(self):
        self.items = [0]

    def __len__(self):
        return len(self.items) - 1

    def insert(self, val):
        self.items.append(val)  # Insert at the far end
        self.up()

    def up(self):
        """Min"""
        i = len(self)
        while i // 2 > 0:  # Iterating towards zero
            if self.items[i] < self.items[i // 2]:
                self.items[i], self.items[i // 2] = self.items[i // 2], self.items[i]
            i = i // 2  # Decrease the index with half length

    def up(self):
        """Max"""
        i = len(self)
        while i // 2 > 0:
            if self.items[i] > self.items[i // 2]:
                self.items[i], self.items[i // 2] = self.items[i // 2], self.items[i]
            i = i // 2

    def down(self, i):
        """Min"""
        while 2 * i <= len(self):  # Iterating towards max, double the length
            mi = self.minimum(i)
            if self.items[i] > self.items[mi]:
                self.items[i], self.items[mi] = self.items[mi], self.items[i]
            i = mi

    def down(self, i):
        """Max"""
        while 2 * i <= len(self):
            mc = self.maximum(i)
            if self.items[i] < self.items[mc]:
                self.items[i], self.items[mc] = self.items[mc], self.items[i]
            i = mc

    def minimum(self, i):
        """Min"""
        if 2 * i + 1 > len(self):
            return 2 * i
        if self.items[2 * i] < self.items[2 * i + 1]:
            return 2 * i
        return 2 * i + 1

    def maximum(self, i):
        """Max"""
        if 2 * i + 1 > len(self):
            return 2 * i
        if self.items[2 * i] > self.items[2 * i + 1]:
            return 2 * i
        return 2 * i + 1

    def heapify(self):
        """Min"""
        i = len(self) // 2
        while i > 0:  # Iterate towards zeo
            self.down(i)
            i = i - 1

    def heapify(self):
        """Max"""
        i = len(self) // 2
        while i > 0:
            self.down(i)
            i = i - 1

    def extract_Min(self):
        """Min"""
        if len(self) == 1:
            return str('cannot extract_Min no elements present')
        value = self.items[1]
        self.items[1] = self.items[len(self)]
        self.items.pop()
        self.down(1)
        return value

    def extract_Max(self):
        """Max"""
        if len(self) == 1:
            return str('cannot extract_Max no elements present')
        value = self.items[1]
        self.items[1] = self.items[len(self)]
        self.items.pop()
        self.down(1)
        return value

    def heapify(self):
        i = len(self) // 2
        while i > 0:
            self.down(i)
            i = i - 1

    def remove(self):
        pass

    def sort(self):
        pass

    def search(self):
        pass


class Heap:
    """Heap class that uses a flattened list for its B-Tree.

    If 'index' is the index of the parent node,
    then '2 * index' is the index of the left child node,
    and '2 * index + 1' is the index of the right child node.

    If 'index' is the index of a child node,
    then 'index // 2' is the index of the parent node.
    The parent node is rounded down towards the least integer,
    therefore the index could be either left or right binary child index.

    """
    def __init__(self):
        self.__heap = [0]

    def __len__(self):
        return len(self.__heap) - 1

    def insert(self, record):
        """Insert a new record at the end of the heap.

        Args:
            record:
                The record to be stored on the heap.

        """
        self.__heap.append(record)  # Insert at the far end
        self.up()

    def up(self):
        """Move a child node up in the tree structure, lets child nodes bubble up the structure if easier.

        By iterating from the end of the heap to the beginning with steps according to binary tree length,
        comparing the child node value with the parent value. If child is less than parent, then swap place
        of the nodes.
        """
        index = len(self.__heap)
        while index // 2 > 0:  # While 'parent' is greater than zero (within bounds)
            if self.__heap[index] < self.__heap[index // 2]:  # If 'child' is less than 'parent'
                self.swap(index, index // 2)  # (then) swap place on 'child' and 'parent'
            index = index // 2

    def down(self, index: int):
        """Move a child/parent down in the tree structure, lets parent nodes sink down the structure if heavier.

        By iterating from the index to the end with steps according to binary tree length, comparing the
        children for the lesser value then compare the parent and the least child. If the parent is
        greater than the child, then swap place of the nodes.

        Args:
            index (int):
                Starting position.

        """
        length = len(self.__heap)
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
        if 2 * index + 1 > len(self.__heap):  # if 'right' index is out of bounds
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
        index = len(self.__heap) // 2
        while index > 0:
            self.down(index)
            index = index - 1

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
        if len(self.__heap) == index:
            raise IndexError("Index out of bounds, %s" % index)
        record = self.__heap[index]
        self.__heap[index] = self.__heap[len(self.__heap)]
        self.__heap.pop()
        self.down(index)
        return record

    def search(self, record):
        """Search for a record based on a hash value.

        Args:
            record:
                Record hash value.

        Returns:
            The found record index or 0

        """
        length = len(self.__heap)
        index = 1  # Set start index at root parent node

        while 2 * index <= length:  # While 'left' child is within bounds
            if self.__heap[index] == record:  # Compare index node hash with search hash
                return index  # If record hash matches return index.

            left = 2 * index  # Left child index
            right = left if left + 1 > length else left + 1  # Right child index (within bounds correction)

            if self.__heap[left] >= record:  # If left child is greater or equal to record
                index = left  # Traverse down the left child node
            elif self.__heap[right] < record:  # If right child is less or equal to record
                index = right  # Traverse down the right child node

        return 0

