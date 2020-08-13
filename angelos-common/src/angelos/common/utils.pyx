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
from typing import Callable, Union, Any, List, Tuple


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
    def app_dir():
        """Absolute path to the executed scripts location."""
        return Util.__app_path

    @staticmethod
    def usr_dir():
        """Absolute path to user home directory."""
        return Util.__usr_path

    @staticmethod
    def exe_dir():
        """Absolute path to current working directory."""
        return Util.__exe_path

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
    def is_path(instance):
        """
        check_path is a helper function. Tests for a PathLike and raises a
        standardized TypeError exception.

        Instance    The instanced variable

        Example:
        check_class(result, (Model, BaseModel))
        """
        if not isinstance(instance, os.PathLike):
            raise TypeError(
                "Path like object expected, but got: {0}".format(str(instance))
            )

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
    def exception(error_code: int, debug_info: dict = dict()):
        """Docstring"""
        import warnings
        warnings.warn("Don't use Error.exception()", DeprecationWarning, stacklevel=2)
        raise RuntimeError(error_code, debug_info)

    @staticmethod
    def format_exception(
            exception_type, instance, message="Formated exception", debug_info={}
    ):
        """
        format_exception is a helper function. It will populate and format an
        exception so that it is understandable and include good debug data.

        exception_type  Requiers an exception type
        instance        The class name of current class, or the current
                        instance itself
        message         Simple error message
        debug_info      A dictionary of interesting debug values
        returns         A string to enter into exception

        Example:
        raise format_exception(
            RuntimeError,
            self.__class__.__name__,
            'Unexpected result',
            {
                id: 45654654767,
                user: 'User Name'
            }
        )
        """
        Util.is_class(exception_type, Exception)
        Util.is_type(instance, (object, str))
        Util.is_type(message, str)
        Util.is_type(debug_info, dict)

        debug = []
        for k in debug_info:
            debug.append("{0}: {1}".format(k, debug_info[k]))
        if isinstance(instance, object):
            name = instance.__class__.__name__
        else:
            name = instance
        exc = exception_type(
            '{0}, "{1}" - debug: {2}'.format(name, message, ", ".join(debug))
        )
        return exc

    @staticmethod
    def format_info(event_str, data=None):
        """
        log_format_info is a helper function. It will format an info message
        with support for event data.

        event_str            A string describing the event
        data                A dictionary with info
        returns                string to pass to logger.info()

        Example:
        try:
            ...
        except Exception as e:
            logger.warning(log_format_info(
                e, 'Result missing from function call X'
            ), exc_info=True)
        """
        Util.is_type(event_str, str)
        Util.is_type(data, (dict, type(None)))

        if not data:
            return "{0}.".format(event_str)
        else:
            info = []
            for k in data:
                info.append("{0}: {1}".format(k, data[k]))
            return "{0}. Info: ({1})".format(event_str, ", ".join(info))

    @staticmethod
    def format_error(caught_exception, event_str):
        """
        log_format_error is a helper function. It will format an exception and
        message formatted with help of format_exception().

        caught_exception    An exception
        event_str            A string describing the event
        returns                string to pass to logger.error()

        Example:
        try:
            ...
        except Exception as e:
            logger.warning(log_format_error(
                e, 'Result missing from function call X'
            ), exc_info=True)
        """
        Util.is_type(caught_exception, Exception)
        Util.is_type(event_str, str)

        return "{0}, Class: {1}:{2}".format(
            event_str, str(type(caught_exception)), caught_exception
        )

    @staticmethod
    def print_exception(exc: Exception):
        """Print exception and traceback using the python print() method."""
        print("Critical error. ({})".format(exc))
        traceback.print_exception(type(exc), exc, exc.__traceback__)

    @staticmethod
    def imp_pkg(path):
        """
        imp_pkg is a helper function for importing classes dynamically by
        telling the search path
        path        String that tells where to find the class
        return        Returns a class descriptor

        Example:
        klass = Util.imp_pkg('module.package.Class')
        c_instance = klass()
        """
        Util.is_type(path, str)
        pkg = path.rsplit(".", 1)
        return getattr(importlib.import_module(pkg[0]), pkg[1])

    @staticmethod
    def class_pkg(klass):
        """Docstring"""
        return "{0}.{1}".format(
            klass.__class__.__module__, klass.__class__.__name__
        )

    @staticmethod
    async def coro(callback: Callable, *args, **kwargs) -> Task:
        """Coroutine wrapper for callbacks.

        Args:
            callback (Callable):
                Callback to be wrapped as a coroutine.
            *args (list):
                Argument list
            **kwargs (dict):
             Keyword argument dictionary.

        Returns (Any):
            The returned result from the callback.

        """
        return callback(*args, **kwargs)

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

    @staticmethod
    def shell(command: str, args: list, kind: Callable = lambda x: x.decode()) -> Any:
        """Run a shell subprocess and execute teh command.

        If there is now kind given will return True on success, otherwise the
        value processed by kind.
        Kind should be of type:
            lambda x: somethin(x)
            int
            PurePath
        """
        execute = command.format(*args)
        with subprocess.Popen(
                execute, shell=True, stdout=subprocess.PIPE if kind else None) as proc:
            if proc.returncode:
                raise RuntimeWarning(
                    "With exit code ({}), failed to execute: {}".format(proc.returncode, execute))
            elif kind:
                return kind(proc.stdout.read())
            else:
                return True

    @staticmethod
    def script(run: List[Tuple[str, list]], log: bool = True) -> bool:
        """Execute a script of shell commands."""
        row = ("Nothing", [])
        try:
            for row in run:
                Util.shell(*row, None)
                if log:
                    logging.info(row[0].format(*row[1]))
        except RuntimeWarning as e:
            if log:
                logging.warning(e, exc_info=True)
            return False
        else:
            return True


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
