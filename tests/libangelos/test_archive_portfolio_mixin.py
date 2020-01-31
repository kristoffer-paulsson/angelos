import os
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation
from libangelos.task.task import TaskWaitress

from angelossim.support import Generate, run_async


class TestPortfolioMixin(TestCase):
    count = 5

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        # logging.basicConfig(stream=sys.stderr, level=logging.INFO)

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

    def test_update_portfolio(self):
        self.fail()

    def test_add_portfolio(self):
        self.fail()

    def test_docs_to_portfolio(self):
        self.fail()

    def test_list_portfolios(self):
        self.fail()

    def test_import_portfolio(self):
        self.fail()

    def test_load_portfolio(self):
        self.fail()

    def test_reload_portfolio(self):
        self.fail()

    def test_save_portfolio(self):
        self.fail()

    @run_async
    async def test_delete_portfolio(self):
        try:
            eids = await self.facade.storage.vault.list_portfolios()
            eids -= set([self.portfolio.entity.id])
            await self.facade.storage.vault.delete_portfolio(eids.pop())
        except Exception as e:
            self.fail(e)
