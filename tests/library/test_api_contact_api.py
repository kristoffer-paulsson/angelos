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
import os
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation
from libangelos.policy.portfolio import PGroup
from libangelos.task.task import TaskWaitress

from angelossim.support import Generate, run_async


class TestContactAPI(TestCase):
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

    @run_async
    async def test_load_all(self):
        self.assertEqual(
            await self.facade.storage.vault.list_portfolios() - {self.facade.data.portfolio.entity.id},
            await self.facade.api.contact.load_all()
        )

    @run_async
    async def test_load_blocked(self):
        self.assertEqual(
            await self.facade.api.contact.load_blocked(),
            set()
        )

    @run_async
    async def test_block(self):
        every = await self.facade.api.contact.load_all()
        dummy = next(iter(every))
        await self.facade.api.contact.block(dummy)
        self.assertEqual(dummy, (
            await self.facade.storage.vault.load_portfolio(dummy, PGroup.ALL)
        ).entity.id)
        self.assertIn(dummy, await self.facade.api.contact.load_blocked())
        self.assertNotIn(dummy, await self.facade.api.contact.load_all())

        """dfei = await self.facade.storage.vault.archive.info(
            self.facade.storage.vault.PATH_PORTFOLIOS[0] + str(dummy) + "/" + str(dummy) + ".ent")
        pprint.pprint(dfei)

        dlei = await self.facade.storage.vault.archive.info(
            self.facade.api.contact.PATH_BLOCKED[0] + str(dummy))
        pprint.pprint(dlei)"""

    @run_async
    async def test_unblock(self):
        every = await self.facade.api.contact.load_all()
        dummy = next(iter(every))
        await self.facade.api.contact.block(dummy)
        self.assertIn(dummy, await self.facade.api.contact.load_blocked())
        await self.facade.api.contact.unblock(dummy)
        self.assertIn(dummy, await self.facade.api.contact.load_all())

    @run_async
    async def test_load_friends(self):
        every = await self.facade.api.contact.load_all()
        dummy = next(iter(every))
        await self.facade.api.contact.friend(dummy)
        self.assertEqual(dummy, (
            await self.facade.storage.vault.load_portfolio(dummy, PGroup.ALL)
        ).entity.id)
        self.assertIn(dummy, await self.facade.api.contact.load_all())
        self.assertIn(dummy, await self.facade.api.contact.load_friends())

    @run_async
    async def test_unfriend(self):
        every = await self.facade.api.contact.load_all()
        dummy = next(iter(every))
        await self.facade.api.contact.friend(dummy)
        self.assertIn(dummy, await self.facade.api.contact.load_friends())
        await self.facade.api.contact.unfriend(dummy)
        self.assertNotIn(dummy, await self.facade.api.contact.load_friends())

    @run_async
    async def test_favorite(self):
        every = await self.facade.api.contact.load_all()
        dummy = next(iter(every))
        await self.facade.api.contact.favorite(dummy)
        self.assertEqual(dummy, (
            await self.facade.storage.vault.load_portfolio(dummy, PGroup.ALL)
        ).entity.id)
        self.assertIn(dummy, await self.facade.api.contact.load_all())
        self.assertIn(dummy, await self.facade.api.contact.load_favorites())

    @run_async
    async def test_unfavorite(self):
        every = await self.facade.api.contact.load_all()
        dummy = next(iter(every))
        await self.facade.api.contact.favorite(dummy)
        self.assertIn(dummy, await self.facade.api.contact.load_favorites())
        await self.facade.api.contact.unfavorite(dummy)
        self.assertNotIn(dummy, await self.facade.api.contact.load_favorites())

    @run_async
    async def test_remove(self):
        every = await self.facade.api.contact.load_all()
        dummy = next(iter(every))
        await self.facade.api.contact.favorite(dummy)
        await self.facade.api.contact.friend(dummy)
        self.assertIn(dummy, await self.facade.api.contact.load_favorites())
        self.assertIn(dummy, await self.facade.api.contact.load_friends())
        self.assertIn(dummy, await self.facade.api.contact.load_all())
        await self.facade.api.contact.remove(dummy)
        self.assertNotIn(dummy, await self.facade.api.contact.load_favorites())
        self.assertNotIn(dummy, await self.facade.api.contact.load_friends())
        self.assertNotIn(dummy, await self.facade.api.contact.load_all())
