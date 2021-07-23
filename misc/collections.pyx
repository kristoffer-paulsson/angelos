# cython: language_level=3
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Collections implemented in Cython.

https://docs.python.org/3/library/typing.html
https://docs.python.org/3/library/collections.abc.html

Callable: from collections.abc import Callable
Any
Tuple
Literal
Annotated
AnyStr
Protocol
NamedTuple: from collections import namedtuple
TypedDict
Dict
List
Set
FrozenSet
IO
TextIO
BinaryIO
Pattern
Match
Text
AbstractSet: collections.abc.Set
ByteString: collections.abc.ByteString
Collection: collections.abc.Collection
Container: collections.abc.Container
ItemsView: collections.abc.ItemsView
KeysView: collections.abc.KeysView
Mapping: collections.abc.Mapping
MappingView: collections.abc.MappingView
MutableMapping: collections.abc.MutableMapping
MutableSequence: collections.abc.MutableSequence
MutableSet: collections.abc.MutableSet
Sequence: collections.abc.Sequence
ValuesView: collections.abc.ValuesView
Iterable: collections.abc.Iterable
Iterator: collections.abc.Iterator
Generator
Hashable: collections.abc.Hashable
Reversible: collections.abc.Reversible
Sized: collections.abc.Sized
Coroutine: collections.abc.Coroutine
AsyncGenerator: collections.abc.AsyncGenerator
AsyncIterable: collections.abc.AsyncIterable
AsyncIterator: collections.abc.AsyncIterator
Awaitable: collections.abc.Awaitable
SupportsAbs
SupportsBytes
SupportsComplex
SupportsFloat
SupportsIndex
SupportsInt
SupportsRound
ForwardRef
"""


cdef long TYPE_COUNTER = 0

cdef class Any:
    cdef long _type;
    cdef long _size;

    def __class_getitem__(cls, Any item):
        TYPE_COUNTER += 1
        cls._type = TYPE_COUNTER
        cls._size = sizeof(item)

    def __cinit__(self):
        pass


###

cdef class Hashable:
    def __hash__(self):  # abstract
        return 0


cdef class Awaitable:
    def __await__(self):  # abstract
        yield


cdef class Coroutine(Awaitable):
    cpdef send(self, value):  # abstract
        """Send a value into the coroutine.
        Return next yielded value or raise StopIteration.
        """
        raise StopIteration

    cpdef throw(self, typ, val=None, tb=None):  # abstract
        """Raise an exception in the coroutine.
        Return next yielded value or raise StopIteration.
        """
        if val is None:
            if tb is None:
                raise typ
            val = typ()
        if tb is not None:
            val = val.with_traceback(tb)
        raise val

    cpdef close(self):
        """Raise GeneratorExit inside coroutine.
        """
        try:
            self.throw(GeneratorExit)
        except (GeneratorExit, StopIteration):
            pass
        else:
            raise RuntimeError("coroutine ignored GeneratorExit")


cdef class AsyncIterable:
    def __aiter__(self):  # abstract
        return AsyncIterator()


cdef class AsyncIterator(AsyncIterable):
    async def __anext__(self):  # abstract
        """Return the next item or raise StopAsyncIteration when exhausted."""
        raise StopAsyncIteration

    def __aiter__(self):
        return self


cdef class AsyncGenerator(AsyncIterator):
    async def __anext__(self):
        """Return the next item from the asynchronous generator.
        When exhausted, raise StopAsyncIteration.
        """
        return await self.asend(None)

    async def asend(self, value):  # abstract
        """Send a value into the asynchronous generator.
        Return next yielded value or raise StopAsyncIteration.
        """
        raise StopAsyncIteration

    async def athrow(self, typ, val=None, tb=None):  # abstract
        """Raise an exception in the asynchronous generator.
        Return next yielded value or raise StopAsyncIteration.
        """
        if val is None:
            if tb is None:
                raise typ
            val = typ()
        if tb is not None:
            val = val.with_traceback(tb)
        raise val

    async def aclose(self):
        """Raise GeneratorExit inside coroutine.
        """
        try:
            await self.athrow(GeneratorExit)
        except (GeneratorExit, StopAsyncIteration):
            pass
        else:
            raise RuntimeError("asynchronous generator ignored GeneratorExit")


cdef class Iterable:
    def __iter__(self):  # abstract
        while False:
            yield None


cdef class Iterator(Iterable):
    def __next__(self):  # abstract
        'Return the next item from the iterator. When exhausted, raise StopIteration'
        raise StopIteration

    def __iter__(self):
        return self


cdef class Reversible(Iterable):
    def __reversed__(self):  # abstract
        while False:
            yield None


cdef class Generator:
    def __next__(self):
        """Return the next item from the generator.
        When exhausted, raise StopIteration.
        """
        return self.send(None)

    def send(self, value):  # abstract
        """Send a value into the generator.
        Return next yielded value or raise StopIteration.
        """
        raise StopIteration

    def throw(self, typ, val=None, tb=None):  # abstract
        """Raise an exception in the generator.
        Return next yielded value or raise StopIteration.
        """
        if val is None:
            if tb is None:
                raise typ
            val = typ()
        if tb is not None:
            val = val.with_traceback(tb)
        raise val

    cpdef close(self):
        """Raise GeneratorExit inside generator.
        """
        try:
            self.throw(GeneratorExit)
        except (GeneratorExit, StopIteration):
            pass
        else:
            raise RuntimeError("generator ignored GeneratorExit")


cdef class Sized:
    def __len__(self):  # abstract
        return 0


cdef class Container:
    def __contains__(self, x):  # abstract
        return False


cdef class Collection(Sized, Iterable, Container):
    pass


cdef class Callable:
    def __call__(self, *args, **kwds):  # abstract
        return False


cdef class Set(Collection):
    def __le__(self, other):
        if not isinstance(other, Set):
            return NotImplemented
        if len(self) > len(other):
            return False
        for elem in self:
            if elem not in other:
                return False
        return True

    def __lt__(self, other):
        if not isinstance(other, Set):
            return NotImplemented
        return len(self) < len(other) and self.__le__(other)

    def __gt__(self, other):
        if not isinstance(other, Set):
            return NotImplemented
        return len(self) > len(other) and self.__ge__(other)

    def __ge__(self, other):
        if not isinstance(other, Set):
            return NotImplemented
        if len(self) < len(other):
            return False
        for elem in other:
            if elem not in self:
                return False
        return True

    def __eq__(self, other):
        if not isinstance(other, Set):
            return NotImplemented
        return len(self) == len(other) and self.__le__(other)

    def __and__(self, other):
        if not isinstance(other, Iterable):
            return NotImplemented
        # return self._from_iterable(value for value in other if value in self)

    # __rand__ = __and__

    def isdisjoint(self, other):
        'Return True if two sets have a null intersection.'
        for value in other:
            if value in self:
                return False
        return True

    def __or__(self, other):
        if not isinstance(other, Iterable):
            return NotImplemented
        chain = (e for s in (self, other) for e in s)
        return self._from_iterable(chain)

    # __ror__ = __or__

    def __sub__(self, other):
        if not isinstance(other, Set):
            if not isinstance(other, Iterable):
                return NotImplemented
            other = self._from_iterable(other)
        return self._from_iterable(value for value in self
                                   if value not in other)

    def __rsub__(self, other):
        if not isinstance(other, Set):
            if not isinstance(other, Iterable):
                return NotImplemented
            other = self._from_iterable(other)
        return self._from_iterable(value for value in other
                                   if value not in self)

    def __xor__(self, other):
        if not isinstance(other, Set):
            if not isinstance(other, Iterable):
                return NotImplemented
            other = self._from_iterable(other)
        return (self - other) | (other - self)


cdef class MutableSet(Set):
    cpdef add(self, value):  # abstract
        """Add an element."""
        raise NotImplementedError

    cpdef discard(self, value):  # abstract
        """Remove an element.  Do not raise an exception if absent."""
        raise NotImplementedError

    cpdef remove(self, value):
        """Remove an element. If not a member, raise a KeyError."""
        if value not in self:
            raise KeyError(value)
        self.discard(value)

    cpdef pop(self):
        """Return the popped value.  Raise KeyError if empty."""
        it = iter(self)
        try:
            value = next(it)
        except StopIteration:
            raise KeyError from None
        self.discard(value)
        return value

    cpdef clear(self):
        """This is slow (creates N new iterators!) but effective."""
        try:
            while True:
                self.pop()
        except KeyError:
            pass

    def __ior__(self, it):
        for value in it:
            self.add(value)
        return self

    def __iand__(self, it):
        for value in (self - it):
            self.discard(value)
        return self

    def __ixor__(self, it):
        if it is self:
            self.clear()
        else:
            if not isinstance(it, Set):
                it = self._from_iterable(it)
            for value in it:
                if value in self:
                    self.discard(value)
                else:
                    self.add(value)
        return self

    def __isub__(self, it):
        if it is self:
            self.clear()
        else:
            for value in it:
                self.discard(value)
        return self


cdef class Mapping(Collection):
    def __getitem__(self, key):  # abstract
        raise KeyError

    cpdef get(self, key, default=None):
        'D.get(k[,d]) -> D[k] if k in D, else d.  d defaults to None.'
        try:
            return self[key]
        except KeyError:
            return default

    def __contains__(self, key):
        try:
            self[key]
        except KeyError:
            return False
        else:
            return True

    cpdef keys(self):
        "D.keys() -> a set-like object providing a view on D's keys"
        return KeysView(self)

    cpdef items(self):
        "D.items() -> a set-like object providing a view on D's items"
        return ItemsView(self)

    cpdef values(self):
        "D.values() -> an object providing a view on D's values"
        return ValuesView(self)

    def __eq__(self, other):
        if not isinstance(other, Mapping):
            return NotImplemented
        return dict(self.items()) == dict(other.items())


cdef class MappingView(Sized):
    def __init__(self, mapping):
        self._mapping = mapping

    def __len__(self):
        return len(self._mapping)

    def __repr__(self):
        return '{0.__class__.__name__}({0._mapping!r})'.format(self)


cdef class KeysView(MappingView, Set):
    def __contains__(self, key):
        return key in self._mapping

    def __iter__(self):
        yield from self._mapping


cdef class ItemsView(MappingView, Set):
    def __contains__(self, item):
        key, value = item
        try:
            v = self._mapping[key]
        except KeyError:
            return False
        else:
            return v is value or v == value

    def __iter__(self):
        for key in self._mapping:
            yield (key, self._mapping[key])


cdef class ValuesView(MappingView, Collection):
    def __contains__(self, value):
        for key in self._mapping:
            v = self._mapping[key]
            if v is value or v == value:
                return True
        return False

    def __iter__(self):
        for key in self._mapping:
            yield self._mapping[key]


cdef class MutableMapping(Mapping):
    _marker =None
    def __setitem__(self, key, value):  # abstract
        raise KeyError

    def __delitem__(self, key):  # abstract
        raise KeyError

    cpdef pop(self, key, default=_marker):
        '''D.pop(k[,d]) -> v, remove specified key and return the corresponding value.
          If key is not found, d is returned if given, otherwise KeyError is raised.
        '''
        try:
            value = self[key]
        except KeyError:
            if default is self._marker:
                raise
            return default
        else:
            del self[key]
            return value

    cpdef popitem(self):
        '''D.popitem() -> (k, v), remove and return some (key, value) pair
           as a 2-tuple; but raise KeyError if D is empty.
        '''
        try:
            key = next(iter(self))
        except StopIteration:
            raise KeyError from None
        value = self[key]
        del self[key]
        return key, value

    cpdef clear(self):
        'D.clear() -> None.  Remove all items from D.'
        try:
            while True:
                self.popitem()
        except KeyError:
            pass

    def update(self, other=(), **kwds):
        ''' D.update([E, ]**F) -> None.  Update D from mapping/iterable E and F.
            If E present and has a .keys() method, does:     for k in E: D[k] = E[k]
            If E present and lacks .keys() method, does:     for (k, v) in E: D[k] = v
            In either case, this is followed by: for k, v in F.items(): D[k] = v
        '''
        if isinstance(other, Mapping):
            for key in other:
                self[key] = other[key]
        elif hasattr(other, "keys"):
            for key in other.keys():
                self[key] = other[key]
        else:
            for key, value in other:
                self[key] = value
        for key, value in kwds.items():
            self[key] = value

    cpdef setdefault(self, key, default=None):
        'D.setdefault(k[,d]) -> D.get(k,d), also set D[k]=d if k not in D'
        try:
            return self[key]
        except KeyError:
            self[key] = default
        return default


cdef class Sequence(Reversible, Collection):
    def __getitem__(self, index):  # abstract
        raise IndexError

    def __iter__(self):
        i = 0
        try:
            while True:
                v = self[i]
                yield v
                i += 1
        except IndexError:
            return

    def __contains__(self, value):
        for v in self:
            if v is value or v == value:
                return True
        return False

    def __reversed__(self):
        for i in reversed(range(len(self))):
            yield self[i]

    cpdef index(self, value, start=0, stop=None):
        '''S.index(value, [start, [stop]]) -> integer -- return first index of value.
           Raises ValueError if the value is not present.
           Supporting start and stop arguments is optional, but
           recommended.
        '''
        if start is not None and start < 0:
            start = max(len(self) + start, 0)
        if stop is not None and stop < 0:
            stop += len(self)

        i = start
        while stop is None or i < stop:
            try:
                v = self[i]
                if v is value or v == value:
                    return i
            except IndexError:
                break
            i += 1
        raise ValueError

    def count(self, value):
        'S.count(value) -> integer -- return number of occurrences of value'
        return sum(1 for v in self if v is value or v == value)


cdef class ByteString(Sequence):
    pass


cdef class MutableSequence(Sequence):
    def __setitem__(self, index, value):  # abstract
        raise IndexError

    def __delitem__(self, index):  # abstract
        raise IndexError

    cpdef insert(self, index, value):  # abstract
        'S.insert(index, value) -- insert value before index'
        raise IndexError

    cpdef append(self, value):
        'S.append(value) -- append value to the end of the sequence'
        self.insert(len(self), value)

    cpdef clear(self):
        'S.clear() -> None -- remove all items from S'
        try:
            while True:
                self.pop()
        except IndexError:
            pass

    cpdef reverse(self):
        'S.reverse() -- reverse *IN PLACE*'
        n = len(self)
        for i in range(n//2):
            self[i], self[n-i-1] = self[n-i-1], self[i]

    cpdef extend(self, values):
        'S.extend(iterable) -- extend sequence by appending elements from the iterable'
        if values is self:
            values = list(values)
        for v in values:
            self.append(v)

    cpdef pop(self, index=-1):
        '''S.pop([index]) -> item -- remove and return item at index (default last).
           Raise IndexError if list is empty or index is out of range.
        '''
        v = self[index]
        del self[index]
        return v

    cpdef remove(self, value):
        '''S.remove(value) -- remove first occurrence of value.
           Raise ValueError if the value is not present.
        '''
        del self[self.index(value)]

    def __iadd__(self, values):
        self.extend(values)
        return self


###

cdef class Tuple:
    pass

cdef class Literal:
    pass

cdef class Annotated:
    pass

cdef class AnyStr:
    pass

cdef class Protocol:
    pass

cdef class NamedTuple:
    pass

cdef class TypedDict:
    pass

cdef class Dict(Any[int]):
    pass

class PDict(Dict):
    pass

cdef class List:
    pass

cdef class FrozenSet:
    pass

cdef class IO:
    pass

cdef class TextIO:
    pass

cdef class BinaryIO:
    pass

cdef class Pattern:
    pass

cdef class Match:
    pass

cdef class Text:
    pass

cdef class AbstractSet:
    pass

cdef class SupportsAbs:
    pass

cdef class SupportsBytes:
    pass

cdef class SupportsComplex:
    pass

cdef class SupportsFloat:
    pass

cdef class SupportsIndex:
    pass

cdef class SupportsInt:
    pass

cdef class SupportsRound:
    pass

cdef class ForwardRef:
    pass
