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
"""Module docstring."""
import asyncio
import atexit
import concurrent
import functools
import ipaddress
import logging
import os
import re
import socket
import uuid
from abc import ABC, abstractmethod
from concurrent.futures.thread import ThreadPoolExecutor
from threading import Thread
from typing import Callable, Awaitable, Any, Union, List, Tuple
from urllib.parse import urlparse

import plyer


class Loop:
    """
    Isolated asynchronous loop inside a thread.
    """

    __main = None
    __cnt = 0

    def __init__(self, name=""):
        self.__cnt += 1
        self.__loop = asyncio.new_event_loop()
        self.__thread = Thread(
            target=self.__run, daemon=True, name=name if name else "LoopThread-{}".format(self.__cnt))
        atexit.register(self.__stop)
        self.__thread.start()

    @classmethod
    def main(cls) -> "Loop":
        """Global instance of Loop."""
        if not cls.__main:
            cls.__main = Loop("LoopThread-0")
        return cls.__main

    @property
    def loop(self):
        return self.__loop

    def __run(self) -> None:
        asyncio.set_event_loop(self.__loop)
        self.__loop.run_forever()

    def __stop(self) -> None:
        self.__loop.call_soon_threadsafe(self.__loop.stop)

    def run(
            self, coro: Awaitable,
            callback: Callable[[concurrent.futures.Future], None] = None, wait=False
    ) -> Any:
        future = asyncio.run_coroutine_threadsafe(coro, self.__loop)
        future.add_done_callback(self.__callback)

        if callback:
            future.add_done_callback(callback)

        if wait:
            return future.result()
        else:
            return future

    def __callback(self, future: concurrent.futures.Future):
        exc = future.exception()
        if exc:
            raise exc


class Fiber(ABC):
    """Fiber that execute micro tasks (polymers) synchronously in an executor.

    Subclass the Fiber class and implement your action or operation in the run method.
    All the sub-tasks should be implemented i separate methods decorated with @polymer.
    Those are tasks that will be executed in the executor in parallel with a huge number
    of other fibers maximizing the use of processor capacity.
    """

    __pool = None

    class polymer:
        """Decorator that makes a method run within the pool executor"""
        def __init__(self, exe):
            self.__exe = exe

        async def __call__(self, *args, **kwargs):
            future = Fiber.pool().submit(self.__exe, *args, **kwargs)
            await asyncio.sleep(0)
            return future.result(1)

    @classmethod
    def pool(cls) -> ThreadPoolExecutor:
        """Global instance of Loop."""
        if not cls.__pool:
            cls.__pool = ThreadPoolExecutor(max_workers=os.cpu_count())
        return cls.__pool

    async def start(self):
        """Start the run method of the fiber."""
        await self.run()

    @abstractmethod
    async def run(self):
        """Implement action calling polymers in the fiber."""
        pass


class shared:
    """Shared resource decorator. This decorator makes sure that decorated methods in a resource is not called
    simultaneously."""

    def __init__(self, exe):
        self._exe = exe

    async def __call__(self, *args, **kwargs):
        future = self._obj.pool.submit(self._exe, self._obj, *args, **kwargs)
        await asyncio.sleep(0)
        return future.result(1)

    def __get__(self, instance, owner):
        self._obj = instance
        return self.__call__


class SharedResource:
    """Shared resource is a class mixin that guarantees synchronious execution of sensitive methods in a separate
    thread. It is meant to offload workload from an asyncio event loop and also provide that no class is writing to a
    singleton resource simultaneously, but make sure that every task is performed in the right order.
    """

    def __init__(self):
        self._pool = ThreadPoolExecutor(max_workers=1)

    @property
    def pool(self) -> ThreadPoolExecutor:
        """Expose the pool queue."""
        return self._pool

    def __del__(self):
        self._pool.shutdown()


class SharedResourceMixin:
    """Shared resource is a class that must be shared between threads but must be guaranteed synchronous
    execution. This class is a mixin and all sensitive methods in the main class should be private to
    the outside world, then be called via a public proxy function that calls the _run method. All calls
    via the _run method is handled in a thread pool executor linearly.
    """

    def __init__(self):
        self.__pool = ThreadPoolExecutor(max_workers=1)

    @property
    def pool(self):
        """Expose the pool queue."""
        return self.__pool

    def __del__(self):
        self.__pool.shutdown()

    async def execute(self, callback: Callable, *args, **kwargs) -> Any:
        """Execute a callable method within a thread pool executor.

        Args:
            callback (Callable):
                A callable method.
            *args:
                Passes on whatever arguments.
            *kwargs:
                Passes on whatever keyword arguments.

        Returns (Any):
            Whatever the callback returns.

        """
        return await self._run(functools.partial(callback, *args, **kwargs))

    async def _run(self, callback: Callable) -> Any:
        """Protected method for executing a multi-thread sensitive private method.

        This method handles internal exceptions by logging them and re-raise them.

        Args:
            callback (callable):
                Method that is multi-thread sensitive.

        Returns (Any):
            Whatever return value from inner sensitive method.

        """
        await asyncio.sleep(0)
        return await asyncio.get_running_loop().run_in_executor(self.__pool, callback)

    async def _wild(self, callback: Callable) -> Any:
        """Protected method for executing a multi-thread sensitive private method.

        This method handles internal exceptions by logging them and re-raise them.

        Args:
            callback (callable):
                Method that is multi-thread sensitive.

        Returns (Any):
            Whatever return value from inner sensitive method.

        """
        await asyncio.sleep(0)
        return await asyncio.get_running_loop().run_in_executor(self.__pool, callback)


class BaseData(ABC):
    pass


class ThresholdCounter:
    """
    ThresholdCounter is a helper class that counts ticks and alarms
    when the threshold is reached.
    """
    def __init__(self, threshold=3):
        """
        Initializes an instanceself.
        threshold	An integer defining the threshold.
        """
        self.__cnt = 0
        self.__thr = threshold

    def tick(self):
        """
        Counts one tick.
        """
        self.__cnt += 1

    def reset(self):
        """
        Resets the counter.
        """
        self.__cnt == 0

    def limit(self):
        """
        Returns True when the threshold is met.
        """
        return self.__cnt >= self.__thr


class LazyAttribute:
    """
    Attribute class that allows lazy loading using a lambda.
    """
    def __init__(self, loader: Callable):
        self.__loader = loader
        self.__done = False
        self.__value = None

    def __get__(self, obj, obj_type) -> Any:
        return self.__value if self.__done else self.__load()

    def __load(self) -> Any:
        self.__value = self.__loader()
        self.__done = True
        return self.__value


class SyncCallable:
    """Network callable to get around cython callables."""

    def __init__(self, callback: Callable):
        self._cb = callback

    def __call__(self, *args, **kwargs) -> Any:
        return self._cb(*args, **kwargs)


class AsyncCallable(SyncCallable):
    """Async network callable."""

    async def __call__(self, *args, **kwargs) -> Any:
        return await self._cb(*args, **kwargs)


class Misc:
    """Namespace for miscellaneous functions and methods."""

    REGEX = r"""(?:(?P<username>[\w\-\.]+)(?::(?P<password>[\w\-\.]+))?@)?(?P<hostname>[\w\-\.]+)(?::(?P<port>\d+))?"""

    @staticmethod
    def unique() -> str:
        """Get the hardware ID.

        Tries to find the unique id of the hardware, otherwise returns MAC
        address.

        Returns
        -------
        string
            Unique hardware id.

        """
        try:
            serial = plyer.uniqueid.id
            if isinstance(serial, bytes):
                serial = serial.decode()
            return serial
        except NotImplementedError:
            return str(uuid.getnode())

    @staticmethod
    def get_loop() -> asyncio.AbstractEventLoop:
        """Get running loop or Loop main instance.

        Returns (asyncio.AbstractEventLoop):
            A running loop.
        """
        try:
            return asyncio.get_running_loop()
        except RuntimeError:
            return Loop.main().loop

    @staticmethod
    def urlparse(urlstring: str) -> dict:
        """Parse an angelos url.

        Args:
            urlstring:

        Returns:

        """
        tmp = urlparse(urlstring, scheme="angelos", allow_fragments=False)
        regex = re.match(Misc.REGEX, tmp.netloc).groupdict()
        merged = {**regex, **dict(tmp._asdict())}
        return {k: merged[k] for k in {"scheme", "hostname", "path", "username", "password", "port"}}

    @staticmethod
    def urlunparse(parts: dict) -> str:
        """Build url from parts

        Returns (str):
            Built angelos url.

        """
        netloc = parts["hostname"]
        if parts["username"]:
            if parts["password"]:
                netloc = "{username}:{password}@".format(
                    username=parts["username"], password=parts["password"]) + netloc
            else:
                netloc = "{username}@".format(
                    username=parts["username"]) + netloc

        if parts["port"]:
            netloc += ":{port}".format(port=parts["port"])

        return "{scheme}://{netloc}{path}".format(
            scheme=parts["scheme"], netloc=netloc, path=parts["path"])

    @staticmethod
    def location(url: str) -> Tuple[str, int]:
        """domain and port from url."""
        parts = urlparse("angelos://", url)
        return parts.netloc.split(":")[0], parts.port

    @staticmethod
    def lookup(netloc: str) -> Tuple[ipaddress.IPv4Address, ipaddress.IPv6Address]:
        """IP addresses from domain."""
        return ipaddress.IPv4Address(socket.gethostbyname(netloc)), \
               ipaddress.IPv6Address(socket.getaddrinfo(netloc, None, socket.AF_INET6)[0][4][0])

    @staticmethod
    async def sleep():
        """Sleep one async tick."""
        await asyncio.sleep(0)

    @staticmethod
    def ip() -> List[Union[ipaddress.IPv4Address, ipaddress.IPv6Address]]:
        """Get external, internal and loopback ip address."""
        address = set()
        try:
            for ip in socket.gethostbyname_ex(socket.gethostname())[2]:
                if not ip.startswith("127."):
                    try:
                        address.add(ipaddress.ip_address(ip))
                    except ValueError:
                        continue
                    else:
                        break
        except socket.gaierror:
            pass

        for sock in [socket.socket(socket.AF_INET, socket.SOCK_DGRAM)]:
            try:
                sock.connect(("1.1.1.1", 1))
                address.add(ipaddress.ip_address(sock.getsockname()[0]))
                sock.close()
            except (ValueError, OSError):
                continue
            else:
                break

        address.add(ipaddress.ip_address("127.0.0.1"))

        address = list(address)
        address.sort()
        address.reverse()
        return address

    @staticmethod
    def to_ini(value: Any) -> str:
        """Convert python value to INI string.

        Args:
            value (Any):
                Value to stringify.
        Returns(str):
            INI string.

        """
        if type(value) in (bool, type(None)):
            return str(value).lower()
        else:
            return str(value)

    @staticmethod
    def from_ini(value: str) -> Any:
        """Convert INI string to python value.

        Args:
            value (str):
                INI string to pythonize.
        Returns (Any):
            Python value.

        """
        try:
            return int(value)
        except ValueError:
            pass

        try:
            return float(value)
        except ValueError:
            pass

        value = value.lower()
        if value in ("true", "false", "yes", "no", "on", "off"):
            return value.lower() in ("true", "yes", "on")
        if value == str(None).lower():
            return None

        return value

    @staticmethod
    def recurse_env(obj: Any, suffix: str = "", level: int = 0) -> list:
        """Recurse over the environment."""
        items = []
        for key, value in obj.items():
            if isinstance(value, BaseData):
                items += Misc.recurse_env(vars(value), key, level + 1)
            else:
                items.append(
                    "{k:<24} {v:}".format(
                        k=(suffix + "." if suffix else "") + key + ":", v=value
                    )
                )
        return items


class StateMachine:
    """A class that can hold a single state at a time."""

    def __init__(self):
        self._state = None

    @property
    def state(self) -> str:
        """Get state."""
        return self._state

    @property
    def available(self) -> tuple:
        """Expose available options."""
        raise NotImplementedError()

    def goto(self, state: str):
        """Switch to another state."""
        raise NotImplementedError()


class SingleState(StateMachine):
    """A state machine that allows switching between states."""

    def __init__(self, states: tuple):
        StateMachine.__init__(self)
        self._options = states

    @property
    def available(self) -> tuple:
        """Expose available options."""
        return self._options

    def goto(self, state: str):
        """Go to another state that is available."""
        if state not in self._options:
            raise RuntimeError("State {} not among options".format(state))
        self._state = state


class EventState(SingleState):
    """A state machine that triggers an event at state change."""

    def __init__(self, states: list):
        SingleState.__init__(self, states)
        self._condition = asyncio.Condition()

    def goto(self, state: str):
        """Go to another state and trigger an event."""
        SingleState.goto(self, state)
        self._condition.notify_all()

    async def wait_for(self, predicate):
        """Wait for a state to happen."""
        await self._condition.predicate(predicate)