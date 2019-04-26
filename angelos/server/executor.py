"""Executor handler for the IoC."""
import asyncio
import multiprocessing
import functools
import concurrent.futures


"""
Implement https://stackoverflow.com/questions/52081033/how-to-shutdown-process-with-event-loop-and-executor
"""  # noqa E501


class ExecutorHandler:
    """Thread pool executor class."""

    def __init__(self):
        """Initialize asyncio loop and thread pool."""
        self.__executor = concurrent.futures.ThreadPoolExecutor()
        self.__loop = asyncio.get_event_loop()
        self.__loop.set_default_executor(self.__executor)
        self.__queue = multiprocessing.Queue()
        self.__future = asyncio.ensure_future(self.__end())

    def __call__(self, callback, *args, **kwargs):
        """Add a function/method/coroutine to the event loop."""
        return asyncio.ensure_future(self.__loop.run_in_executor(
            self.__executor, functools.partial(callback, *args, **kwargs)))

    async def __end(self):
        await self.__loop.run_in_executor(self.__executor, self.__queue)

    def stop(self):
        """Stop the executor from running."""
        self.__queue.put(None)
        self.__loop.run_until_complete(self.__future)
        self.__executor.shutdown()
        self.__loop.stop()
        self.__loop.close()
