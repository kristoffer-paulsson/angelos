import asyncio


def run_async(coro):
    """Decorator for asynchronous test cases."""

    def wrapper(*args, **kwargs):
        """Execute the coroutine with asyncio.run()"""
        return asyncio.run(coro(*args, **kwargs))

    return wrapper