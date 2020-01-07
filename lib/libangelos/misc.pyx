# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import abc
import asyncio
import atexit
import concurrent
import functools
import logging
import uuid
from concurrent.futures.thread import ThreadPoolExecutor
from dataclasses import dataclass, asdict as data_asdict
from threading import Thread
from typing import Callable, Awaitable, Any

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
        self.__thread = Thread(target=self.__run, daemon=True, name=name if name else "LoopThread-%s" % self.__cnt)
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
            self,
            coro: Awaitable,
            callback: Callable[[concurrent.futures.Future], None] = None,
            wait=False
    ) -> Any:
        try:
            future = asyncio.run_coroutine_threadsafe(coro, self.__loop)
            future.add_done_callback(self.__callback)

            if callback:
                future.add_done_callback(callback)

            if wait:
                return future.result()
            else:
                return future
        except Exception as e:
            logging.error(e, exc_info=True)
            raise e

    def __callback(self, future: concurrent.futures.Future):
        exc = future.exception()
        if exc:
            logging.error(exc, exc_info=True)


class SharedResource:
    """

    """
    def __init__(self):
        self.__pool = ThreadPoolExecutor(max_workers=1)

    def __del__(self):
        self.__pool.shutdown()

    async def execute(self, callback, *args, **kwargs):
        """

        Args:
            callback:
            *args:
            *kwargs:

        Returns:

        """
        return await self._run(functools.partial(callback, *args, **kwargs))

    async def _run(self, callback):
        """

        Args:
            callback:
            resource:
            *args:
            **kwargs:

        Returns:

        """
        await asyncio.sleep(0)
        return await asyncio.get_running_loop().run_in_executor(self.__pool, callback)


@dataclass
class BaseDataClass(metaclass=abc.ABCMeta):
    """A base dataclass with some basic functions"""

    def _asdict(self) -> dict:
        return data_asdict(self)


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


class Misc:
    """Namespace for miscellanious functions and methods."""
    @staticmethod
    def unique() -> str:
        """Get the hardware ID.

        Tries to find the uniqueid of the hardware, otherwise returns MAC
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
