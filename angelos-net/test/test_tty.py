import asyncio
from unittest import TestCase

from angelos.common.cutil import MetaSafe
from angelos.common.misc import SharedResource, shared
from angelos.meta.testing import run_async

from misc.term import Terminal


class DasTermServ(SharedResource, Terminal):
    """Pseudo terminal with sync."""

    __dict__ = dict()

    def __init__(self, cols: int = 80, lines: int = 24):
        # super().__init__(cols=cols, lines=lines)
        SharedResource.__init__(self)
        Terminal.__init__(self, cols, lines)

    @shared
    def hello(self):
        print("Hello, world!")
        return "ok"


class TestTTY(TestCase):

    @run_async
    async def test_tty(self):
        das = DasTermServ()
        print(await (das.hello()))
