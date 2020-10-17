#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
import logging
import os
import sys
import tracemalloc
from collections import OrderedDict
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation, SetupChurchOperation
from libangelos.policy.portfolio import PGroup
from libangelos.policy.verify import StatementPolicy
from libangelos.task.task import TaskWaitress

from angelossim.support import Generate, run_async, Operations


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

            cls.portfolios.append(SetupChurchOperation.create(Generate.church_data(1)[0]))

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
             await self.facade.storage.vault.add_portfolio(portfolio.to_portfolio())
        await TaskWaitress().wait_for(self.facade.task.contact_sync)

    def tearDown(self) -> None:
        if not self.facade.closed:
            self.facade.close()
        self.dir.cleanup()

    @run_async
    async def test__run(self):
        docs = set()

        # Mutual trust
        docs.add(StatementPolicy.trusted(self.portfolio, self.portfolios[0]))
        docs.add(StatementPolicy.trusted(self.portfolios[0], self.portfolio))

        # One sided trust from facade
        docs.add(StatementPolicy.trusted(self.portfolio, self.portfolios[1]))

        # One sided trust not from facade
        docs.add(StatementPolicy.trusted(self.portfolios[2], self.portfolio))

        # Mutual trust but no network
        docs.add(StatementPolicy.trusted(self.portfolio, self.portfolios[3]))
        docs.add(StatementPolicy.trusted(self.portfolios[3], self.portfolio))

        await self.facade.storage.vault.load_portfolio(self.portfolio.entity.id, PGroup.ALL)

        await self.facade.storage.vault.docs_to_portfolio(docs)
        await TaskWaitress().wait_for(self.facade.task.network_index)

        networks = OrderedDict(await self.facade.api.settings.networks())

        self.assertTrue(networks[str(self.portfolios[0].entity.id)])
        self.assertFalse(networks[str(self.portfolios[1].entity.id)])
        self.assertFalse(networks[str(self.portfolios[2].entity.id)])
        self.assertNotIn(str(self.portfolios[3].entity.id), networks)
