# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""
Utility module.

The utility module containse all minor extras that is used globally in the
application.
"""
import asyncio
import datetime
import importlib
import logging
import os
import subprocess
import sys
import traceback
from asyncio import Task
from os import PathLike
from typing import Callable, Union, Any, List, Tuple, Type


class Event(asyncio.Event):
    """A threadsafe asynchronous event class."""

    # TODO: Mitigate to misc.pyx

    def set(self):
        self._loop.call_soon_threadsafe(super().set)


class Util:
    """General basic utilities."""

    __app_path = os.path.dirname(os.path.abspath(sys.argv[0]))
    __usr_path = os.path.expanduser("~")
    __exe_path = os.path.abspath(os.getcwd())

    @staticmethod
    def path(dirname, filename):
        """Merge directory path and filename."""
        return os.path.join(dirname, filename)

    @staticmethod
    def is_type(instance, types):
        """
        check_type is a helper function. Tests for an instance and raises a
        standardized TypeError exception.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them

        Example:
        check_type(result, (NoneType, StringType))
        """
        if not isinstance(instance, types):
            raise TypeError(
                "Instance expected type {0}, but got: {1}".format(
                    str(types), str(instance)
                )
            )

    @staticmethod
    def is_class(instance, types):
        """
        check_class is a helper function. Tests for a subclass and raises a
        standardized TypeError exception.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them

        Example:
        check_class(result, (Model, BaseModel))
        """
        if not issubclass(instance, types):
            raise TypeError(
                "Subclass expected type {0}, but got: {1}".format(
                    str(types), str(instance)
                )
            )

    def is_typing(instance, types):
        """
        Check instance, even on typing classes.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them
        """
        if isinstance(types, "_GenericAlias"):
            return isinstance(instance, types.__args__)
        else:
            return isinstance(instance, types)

    @staticmethod
    def populate(klass: object, attributes: dict) -> None:
        """
        Populate class attributes from dictionary.

        Args:
            klass:
            attributes:
        """
        for attr, value in attributes.items():
            if hasattr(klass, attr):
                setattr(klass, attr, value)

    @staticmethod
    def print_exception(exc: Exception):
        """Print exception and traceback using the python print() method."""
        print("Critical error. ({})".format(exc))
        traceback.print_exception(type(exc), exc, exc.__traceback__)

    # TODO: Deprecate this one.
    @staticmethod
    def class_pkg(klass):
        """Docstring"""
        return "{0}.{1}".format(
            klass.__class__.__module__, klass.__class__.__name__
        )

    @staticmethod
    def klass(module: str, cls: str) -> Type[Any]:
        """Load a class from a module in a package."""
        return getattr(importlib.import_module(module), cls)

    @staticmethod
    def hours(seconds):
        """Docstring"""
        datetime.timedelta(seconds=seconds)

    @staticmethod
    def headline(title: str, filler: str = "", barrier = "-"):
        """Print headlines."""
        title = " " + title + " " + (filler + " " if filler else "")
        line = barrier * 79
        offset = int(79 / 2 - len(title) / 2)
        return line[:offset] + title + line[offset + len(title):]

    @staticmethod
    def generate_checksum(data: Union[bytes, bytearray]) -> bytes:
        """Generate a checksum out of the entered data."""
        return bytes([sum(data) & 0xFF])

    @staticmethod
    def verify_checksum(data: Union[bytes, bytearray], checksum: bytes) -> bool:
        """Verify the checksum out of the entered data."""
        return bytes([sum(data) & 0xFF]) == checksum


class FactoryInterface:
    """Docstring"""

    # TODO: Mitigate to misc.pyx

    @classmethod
    def factory(cls, **kwargs):
        """Docstring"""
        return cls(kwargs["io"])


class Checksum:
    """Generate and check checksum based on introspection of data stream."""

    # TODO: Mitigate to misc.pyx

    def __init__(self):
        self.__sum = 0

    def introspect(self, stream: Union[bytes, bytearray]):
        """Build checksum based on a stream with multiple data chunks."""
        self.__sum += sum(stream)

    def checksum(self, length: int = 1) -> bytes:
        """Generate a checksum of certain byte size."""
        return (self.__sum & int.from_bytes(b"\xFF" * length, "big")).to_bytes(length, "big")

    def check(self, sum: bytes) -> bool:
        """Compare introspected sum with given sum."""
        return self.checksum(len(sum)) == sum


class StateMachine:
    """A class that can hold a single state at a time."""

    def __init__(self):
        self.__state = None


class SingleState(StateMachine):
    """A state machine that allows switching between states."""

    def __init__(self, states: list):
        StateMachine.__init__(self)
        self.__options = states

    def goto(self, state: str):
        """Go to another state that is available"""
        if state not in self.__options:
            raise RuntimeError("State {} not among options".format(state))
        self.__state = state


class EventState(SingleState):
    """A state machine that triggers an event at state change."""

    def __init__(self, states: list):
        SingleState.__init__(self, states)
        self.__condition = asyncio.Condition()

    def goto(self, state: str):
        """Go to another state and trigger an event."""
        SingleState.goto(self, str)
        self.__condition.notify_all()

    async def wait_for(self, predicate):
        """Wait for a state to happen."""
        await self.__condition.predicate(predicate)
