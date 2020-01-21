import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation, SetupChurchOperation
from libangelos.policy.verify import StatementPolicy
from libangelos.task.task import TaskWaitress

from dummy.support import Generate, run_async


class TestNetworkIndexerTask(TestCase):
    count = 3

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.INFO)

        cls.secret = os.urandom(32)
        cls.server = False
        cls.portfolios = list()
        cls.portfolio = None

        @run_async
        async def portfolios():
            """Generate a facade and inject random contacts."""
            cls.portfolio = SetupPersonOperation.create(Generate.person_data()[0], server=cls.server)

            for person in Generate.church_data(cls.count):
                cls.portfolios.append(SetupChurchOperation.create(person, server=True))

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
    async def test__run(self):
        try:
            docs = set()
            docs.add(StatementPolicy.verified(self.portfolio, self.portfolios[0]))
            docs.add(StatementPolicy.verified(self.portfolios[0], self.portfolio))
            docs.add(StatementPolicy.trusted(self.portfolio, self.portfolios[0]))
            docs.add(StatementPolicy.trusted(self.portfolios[0], self.portfolio))
            print(self.portfolios[0].entity.id)

            docs.add(StatementPolicy.verified(self.portfolio, self.portfolios[1]))
            docs.add(StatementPolicy.trusted(self.portfolio, self.portfolios[1]))
            print(self.portfolios[1].entity.id)

            docs.add(StatementPolicy.verified(self.portfolios[2], self.portfolio))
            docs.add(StatementPolicy.trusted(self.portfolios[2], self.portfolio))
            print(self.portfolios[2].entity.id)

            await self.facade.storage.vault.docs_to_portfolio(docs)
            await TaskWaitress().wait_for(self.facade.task.network_index)

            print((await self.facade.storage.vault.load_settings("networks.csv")).getvalue())
        except Exception as e:
            self.fail(e)
