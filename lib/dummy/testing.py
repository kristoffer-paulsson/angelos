# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Testcase base classes for simplified unit testing."""
import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation
from libangelos.task.task import TaskWaitress

from dummy.support import run_async, Generate
from unittest import TestCase


class BaseTestFacade(TestCase):
    """Base test for facade based unit testing."""

    secret = b""
    server = False
    count = 0
    portfolios = list()
    portfolio = None

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.INFO)

        cls.secret = os.urandom(32)

        @run_async
        async def setup():
            """Generate a facade and inject random contacts."""
            cls.portfolio = SetupPersonOperation.create(Generate.person_data()[0], server=cls.server)

            for entity in range(cls.count):
                cls.portfolios.append(SetupPersonOperation.create(Generate.person_data()[0], server=False))

        setup()

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
