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
import ipaddress
import logging
import re
import socket
import uuid
from concurrent.futures.thread import ThreadPoolExecutor
from dataclasses import dataclass, asdict as data_asdict
from threading import Thread
from typing import Callable, Awaitable, Any, Union, List
from urllib.parse import urlparse

import plyer
from libangelos.document.domain import Node, Network


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
        try:
            return await asyncio.get_running_loop().run_in_executor(self.__pool, callback)
        except Exception as e:
            logging.error(e, exc_info=True)
            raise RuntimeError(e)


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
        merged = {**regex, **tmp._asdict()}
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
        return address

    @staticmethod
    def iploc(doc: Union[Node, Network]) -> Union[ipaddress.IPv4Address, ipaddress.IPv6Address]:
        """IP address for a location from a Node or Network document."""
        if isinstance(doc, Network):
            return [ip for host in doc.hosts for ip in host if ip]
        else:
            return [ip for ip in (doc.location.ip if doc.location else []) if ip]

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
        if is_int(value):
            return int(value)
        elif is_float(value):
            return float(value)
        elif is_bool(value):
            return to_bool(value)
        elif is_none(value):
            return None
        else:
            return value


# ATTRIBUTION
#
# The following section is copied from the "localconfig" project:
# https://github.com/maxzheng/localconfig.git
# Copyright (c) 2014 maxzheng
# Licensed under the MIT license

def is_float(value):
    """Checks if the value is a float """
    return _is_type(value, float)

def is_int(value):
    """Checks if the value is an int """
    return _is_type(value, int)

def is_bool(value):
    """Checks if the value is a bool """
    return value.lower() in ['true', 'false', 'yes', 'no', 'on', 'off']

def is_none(value):
    """Checks if the value is a None """
    return value.lower() == str(None).lower()

def to_bool(value):
    """Converts value to a bool """
    return value.lower() in ['true', 'yes', 'on']

def _is_type(value, t):
    try:
        t(value)
        return True
    except Exception:
        return False