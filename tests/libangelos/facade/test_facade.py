import os
import asyncio
import tracemalloc

from pprint import pprint
from unittest import TestCase
from tempfile import TemporaryDirectory

from libangelos.const import Const
from libangelos.facade.facade import Facade

from libangelos.operation.setup import SetupChurchOperation, SetupPersonOperation, SetupMinistryOperation

from dummy.support import Generate


class TestFacade(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.server = False

    def _portfolio(self):
        return SetupPersonOperation.create(Generate.person_data()[0], server=self.server)

    async def _setup(self, portfolio):
        return await Facade.setup(
                self.home, self.secret,
                Const.A_ROLE_PRIMARY, self.server, portfolio=portfolio
            )

    async def _open(self):
        return await Facade.open(self.home, self.secret)

    def tearDown(self) -> None:
        self.dir.cleanup()

    def test_setup(self):
        async def test():
            try:
                portfolio = self._portfolio()
                facade = await self._setup(portfolio)
                facade.close()
            except Exception as e:
                self.fail(e)

        asyncio.run(test())

    def test_open(self):
        async def test():
            try:
                portfolio = self._portfolio()
                facade = await self._setup(portfolio)
                facade.close()


                facade = await self._open()
                facade.close()
            except Exception as e:
                self.fail(e)

        asyncio.run(test())
