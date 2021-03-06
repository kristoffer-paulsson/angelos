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
import copy
import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.lib.const import Const
from angelos.lib.facade.facade import Facade
from angelos.lib.task.task import TaskWaitress
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async


class BaseTestFacade(TestCase):
    """Base test for facade based unit testing."""
    count = 1
    provision = True

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.INFO)

        cls.secret = os.urandom(32)
        cls.server = False
        cls._portfolios = list()

        @run_async
        async def portfolios():
            """Generate a facade and inject random contacts."""
            for person in Generate.person_data(cls.count):
                cls._portfolios.append(SetupPersonOperation.create(person, server=cls.server))

        portfolios()

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""

    @run_async
    async def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""
        portfolios = copy.deepcopy(self._portfolios)
        self.portfolio = portfolios.pop()
        self.portfolios = portfolios

        self.dir = TemporaryDirectory()
        self.home = self.dir.name

        self.facade = await Facade.setup(
            self.home, self.secret,
            Const.A_ROLE_PRIMARY, self.server, portfolio=self.portfolio
        )

        if self.provision:
            print("Do provision")
            for portfolio in self.portfolios:
                await self.facade.storage.vault.add_portfolio(portfolio)
            await TaskWaitress().wait_for(self.facade.task.contact_sync)

    def tearDown(self) -> None:
        """Tear down after the test."""
        if not self.facade.closed:
            self.facade.close()
        self.dir.cleanup()

        self.portfolios = list()
        self.portfolio = None