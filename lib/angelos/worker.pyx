# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Asynchronous multithreaded worker."""
import asyncio
import logging
import threading
import multiprocessing
import concurrent.futures
import functools

from .utils import Event
from .ioc import ContainerAware


class Worker(ContainerAware):
    """Worker with a private thread, loop and executor."""

    __exit = Event()
    __workers = {}

    def __init__(self, name, ioc, executor=None, new=True):
        """Initialize worker."""
        ContainerAware.__init__(self, ioc)

        if name in self.__workers.keys():
            raise RuntimeError('Worker name is taken: %s' % name)

        if isinstance(executor, int):
            self.__executor = concurrent.futures.ThreadPoolExecutor(
                max_workers=(None if executor == 0 else executor))
            self.__queue = multiprocessing.Queue()
            executor = True

        if not new:
            self.__loop = asyncio.get_event_loop()
            self.__loop.set_exception_handler(self.__loop_exc_handler)
            self.__thread = threading.main_thread()

            if executor:
                self.__future = asyncio.ensure_future(
                    self.__end(), loop=self.__loop)
                self.__loop.set_default_executor(self.__executor)

            asyncio.run_coroutine_threadsafe(self.__quiter(), self.__loop)
        else:
            self.__loop = asyncio.new_event_loop()
            self.__loop.set_exception_handler(self.__loop_exc_handler)

            if executor:
                self.__future = asyncio.ensure_future(
                    self.__end(), loop=self.__loop)
                self.__loop.set_default_executor(self.__executor)

            asyncio.run_coroutine_threadsafe(self.__quiter(), self.__loop)
            self.__thread = threading.Thread(
                target=self.__run, name=name
            ).start()

        self.__workers[name] = self

    @property
    def workers(self):
        """Access to all workers."""
        return self.__workers

    @property
    def loop(self):
        """Access to the loop object."""
        return self.__loop

    @property
    def thread(self):
        """Accress to the thread object."""
        return self.__thread

    def __loop_exc_handler(self, loop, context):
        exc1 = None
        exc2 = None

        logging.critical(context.message)

        if context.exception:
            exc1 = context.exception
        if context.future:
            exc2 = context.future.exception()

        if exc1 == exc2 and exc1 is not None:
            logging.exception(exc1)
        else:
            logging.exception(exc1)
            logging.exception(exc2)

    def __run(self):
        try:
            self.__loop.run_forever()
        except KeyboardInterrupt:
            pass
        except Exception as e:
            logging.critical(
                '%s crashed due to: %s' % (self.__thread.name, e))
            logging.exception(e)

        self.__queue.put(None)
        self.__loop.call_soon(self.__future)
        self.__loop.run_until_complete(self.__loop.shutdown_asyncgens())
        self.__executor.shutdown()
        self.__loop.stop()
        self.__loop.close()

        self.__workers.pop(self.__thread.name)

    async def __end(self):
        await self.__loop.run_in_executor(self.__executor, self.__queue)

    async def __quiter(self):
        await self.__exit.wait()
        raise KeyboardInterrupt()

    def call_soon(self, callback, *args, context=None):
        """Threadsafe version of call_soon."""
        self.__loop.call_soon_threadsafe(callback, *args, context=context)

    def run_coroutine(self, coro):
        """Threadsafe version of run_coroutine."""
        return asyncio.run_coroutine_threadsafe(coro, self.__loop)

    async def run_in_executor(self, callback, *args, **kwargs):
        """Add a function/method/coroutine to the event loop."""
        return await self.__loop.run_in_executor(
            self.__executor, functools.partial(callback, *args, **kwargs))
