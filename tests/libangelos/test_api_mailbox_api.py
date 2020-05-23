#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation
from libangelos.policy.message import EnvelopePolicy, MessagePolicy
from libangelos.task.task import TaskWaitress

from angelossim.support import Generate, run_async


class TestMailboxAPI(TestCase):
    count = 5

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

    async def _dummy_mail(self, amount=1):
        for person in Generate.person_data():
            portfolio = SetupPersonOperation.create(person, server=False)
            await self.facade.storage.vault.add_portfolio(portfolio)
            for _ in range(amount):
                await self.facade.api.mailbox.import_envelope(
                    EnvelopePolicy.wrap(
                        portfolio,
                        self.facade.data.portfolio,
                        MessagePolicy.mail(portfolio, self.facade.data.portfolio).message(
                            Generate.filename(postfix="."),
                            Generate.lipsum().decode(),
                        ).done(),
                    )
                )

    @run_async
    async def test_load_inbox(self):
        self.fail()

    @run_async
    async def test_load_outbox(self):
        self.fail()

    @run_async
    async def test_load_read(self):
        self.fail()

    @run_async
    async def test_load_drafts(self):
        self.fail()

    @run_async
    async def test_load_trash(self):
        self.fail()

    @run_async
    async def test_load_sent(self):
        self.fail()

    @run_async
    async def test_get_info_inbox(self):
        try:
            await self._dummy_mail()
            letters = await self.facade.api.mailbox.load_inbox()
            await self.facade.api.mailbox.get_info_inbox(letters.pop())
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_get_info_outbox(self):
        self.fail()

    @run_async
    async def test_get_info_read(self):
        self.fail()

    @run_async
    async def test_get_info_draft(self):
        self.fail()

    @run_async
    async def test_get_info_trash(self):
        self.fail()

    @run_async
    async def test_mail_to_inbox(self):
        self.fail()

    @run_async
    async def test_load_envelope(self):
        self.fail()

    @run_async
    async def test_load_message(self):
        self.fail()

    @run_async
    async def test__load_doc(self):
        self.fail()

    @run_async
    async def test_save_outbox(self):
        self.fail()

    @run_async
    async def test_save_sent(self):
        self.fail()

    @run_async
    async def test_save_draft(self):
        self.fail()

    @run_async
    async def test_import_envelope(self):
        self.fail()

    @run_async
    async def test_open_envelope(self):
        try:
            await self._dummy_mail()
            letters = await self.facade.api.mailbox.load_inbox()
            await self.facade.api.mailbox.open_envelope(letters.pop())
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_store_letter(self):
        self.fail()

    @run_async
    async def test_save_read(self):
        self.fail()
