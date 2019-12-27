import os
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation

from dummy.support import Generate
from task.task import TaskWaitress
from tests.libangelos.common import run_async


class TestContactAPI(TestCase):
    count = 5
    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()

        cls.secret = os.urandom(32)
        cls.server = False
        cls.portfolios = list()
        cls.portfolio = None

        @run_async
        async def portfolios():
            """Generate a facade and inject random contacts."""
            cls.portfolio = SetupPersonOperation.create(Generate.person_data()[0], server=cls.server)

            for person in Generate.person_data(cls.count):
                cls.portfolios.append(SetupPersonOperation.create(person, server=cls.server))

        portfolios()

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""

    @run_async
    async def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.home = self.dir.name

        self.facade = await Facade.setup(
            self.home, self.secret,
            Const.A_ROLE_PRIMARY, self.server, portfolio=self.portfolio
        )

        for portfolio in self.portfolios:
            await self.facade.storage.vault.add_portfolio(portfolio)
        await TaskWaitress().wait_for(self.facade.task.contact_sync)

    def tearDown(self) -> None:
        if not self.facade.closed:
            self.facade.close()
        self.dir.cleanup()

    @run_async
    async def test_load_all(self):
        try:
            self.assertEqual(
                await self.facade.storage.vault.list_portfolios(),
                await self.facade.api.contact.load_all()
            )
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_load_blocked(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_block(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_unblock(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_load_friends(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_unfriend(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_favorite(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_unfavorite(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_remove(self):
        try:
            pass
        except Exception as e:
            self.fail(e)
