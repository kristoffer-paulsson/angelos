"""Asynchronous multithreaded worker."""
import asyncio
import threading
import multiprocessing
import concurrent.futures
import functools
import logging

from .ioc import ContainerAware


class Worker(ContainerAware):
    """Worker with a private thread, loop and executor."""

    __exit = asyncio.Event()
    __workers = {}

    def __init__(self, name, ioc, executor=None, new=True):
        """Initialize worker."""
        ContainerAware.__init__(ioc)

        if name in self.__workers.keys():
            raise RuntimeError('Worker name is taken: %s' % name)

        if isinstance(executor, int):
            self.__executor = concurrent.futures.ThreadPoolExecutor(
                max_workers=(None if executor == 0 else executor))
            self.__queue = multiprocessing.Queue()
            executor = True

        if not new:
            self.__loop = asyncio.get_event_loop()
            self.__thread = threading.main_thread()

            if executor:
                self.__future = asyncio.ensure_future(
                    self.__end(), loop=self.__loop)
                self.__loop.set_default_executor(self.__executor)

            self.__loop.call_soon(self.__quited)
        else:
            self.__loop = asyncio.new_event_loop()

            if executor:
                self.__future = asyncio.ensure_future(
                    self.__end(), loop=self.__loop)
                self.__loop.set_default_executor(self.__executor)

            self.__loop.call_soon_threadsafe(self.__quiter)
            self.__thread = threading.Thread(
                target=self.__run, name=name
            ).start()

        self.__workers[self.__thread.name] = self

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
