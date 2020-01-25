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
from unittest import TestCase

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.misc import BaseDataClass, Misc
from libangelos.operation.setup import SetupPersonOperation
from libangelos.policy.verify import StatementPolicy
from libangelos.task.task import TaskWaitress

from dummy.stub import StubServer, StubClient
from dummy.support import run_async, Generate


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


class ApplicationContext:
    """Environmental context for a stub application."""

    app = None
    dir = None
    secret = None

    def __init__(self, tmp_dir, secret, app):
        self.dir = tmp_dir
        self.secret = secret
        self.app = app

    @classmethod
    async def setup(cls, app_cls, data: BaseDataClass):
        secret = os.urandom(32)
        tmp_dir = TemporaryDirectory()
        app = await app_cls.create(tmp_dir.name, secret, data)
        return cls(tmp_dir, secret, app)

    def __del__(self):
        if self.app:
            self.app.stop()
        self.dir.cleanup()


class BaseTestNetwork(TestCase):
    """Base test for facade based unit testing."""

    pref_connectable = False

    server = None
    client = None

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

    @run_async
    async def setUp(self) -> None:
        self.server = await ApplicationContext.setup(StubServer, Generate.church_data()[0])
        self.client = await ApplicationContext.setup(StubClient, Generate.person_data()[0])

        if self.pref_connectable:
            server_portfolio = self.server.app.ioc.facade.data.portfolio
            client_portfolio = self.client.app.ioc.facade.data.portfolio

            docs = set()
            docs.add(StatementPolicy.trusted(server_portfolio, client_portfolio))
            docs.add(StatementPolicy.trusted(client_portfolio, server_portfolio))

            await self.server.app.ioc.facade.storage.vault.import_portfolio(client_portfolio.to_portfolio())
            await self.client.app.ioc.facade.storage.vault.import_portfolio(server_portfolio.to_portfolio())

            # await self.facade.storage.vault.docs_to_portfolio(docs)
            await TaskWaitress().wait_for(self.server.app.ioc.facade.task.contact_sync)
            await TaskWaitress().wait_for(self.client.app.ioc.facade.task.contact_sync)
            await TaskWaitress().wait_for(self.client.app.ioc.facade.task.network_index)
            self.client.app.ioc.facade.data.client["CurrentNetwork"] = server_portfolio.entity.id

        await Misc.sleep()

    def tearDown(self) -> None:
        del self.client
        del self.server
