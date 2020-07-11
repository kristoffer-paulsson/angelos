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
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.api.contact import ContactAPI
from libangelos.policy.types import PersonData, MinistryData, ChurchData

from libangelos.api.mailbox import MailboxAPI
from libangelos.api.replication import ReplicationAPI
from libangelos.api.settings import SettingsAPI
from libangelos.storage.ftp import FtpStorage
from libangelos.storage.home import HomeStorage
from libangelos.storage.mail import MailStorage
from libangelos.storage.pool import PoolStorage
from libangelos.storage.routing import RoutingStorage
from libangelos.storage.vault import VaultStorage
from libangelos.const import Const
from libangelos.data.client import ClientData
from libangelos.data.portfolio import PortfolioData
from libangelos.data.prefs import PreferencesData
from libangelos.data.server import ServerData
from libangelos.facade.facade import Facade, ServerFacadeMixin, ClientFacadeMixin
from libangelos.operation.setup import SetupPersonOperation, SetupMinistryOperation, SetupChurchOperation
from libangelos.task.contact_sync import ContactPortfolioSyncTask

from tests.support.generate import Generate, run_async


class TestFacade(TestCase):
    TYPES = (
        (SetupPersonOperation, Generate.person_data, PersonData),
        (SetupMinistryOperation, Generate.ministry_data, MinistryData),
        (SetupChurchOperation, Generate.church_data, ChurchData)
    )

    @classmethod
    def setUpClass(cls) -> None:
        # logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
        tracemalloc.start()

    def set_up(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = self.dir.name

    def tear_down(self) -> None:
        self.dir.cleanup()

    def _portfolio(self, current_type, server):
        data = current_type[1]()[0]
        inst = current_type[2](**data)
        return current_type[0].create(inst, server=server)

    async def _setup(self, portfolio, server):
        return await Facade.setup(
            self.home, self.secret,
            Const.A_ROLE_PRIMARY, server, portfolio=portfolio
        )

    async def _open(self):
        return await Facade.open(self.home, self.secret)

    def _assert_extension(self, facade):
        self.assertIsInstance(facade.storage.vault, VaultStorage)
        self.assertIsInstance(facade.data.portfolio, PortfolioData)
        self.assertIsInstance(facade.data.prefs, PreferencesData)
        self.assertIsInstance(facade.api.contact, ContactAPI)
        self.assertIsInstance(facade.api.settings, SettingsAPI)
        self.assertIsInstance(facade.api.mailbox, MailboxAPI)
        self.assertIsInstance(facade.api.replication, ReplicationAPI)
        self.assertIsInstance(facade.task.contact_sync, ContactPortfolioSyncTask)

        if isinstance(facade, ServerFacadeMixin):
            self.assertIsInstance(facade.storage.routing, RoutingStorage)
            self.assertIsInstance(facade.storage.pool, PoolStorage)
            self.assertIsInstance(facade.storage.mail, MailStorage)
            self.assertIsInstance(facade.storage.ftp, FtpStorage)
            self.assertIsInstance(facade.data.server, ServerData)

        if isinstance(facade, ClientFacadeMixin):
            self.assertIsInstance(facade.storage.home, HomeStorage)
            self.assertIsInstance(facade.data.client, ClientData)

    @run_async
    async def test_setup(self):
        for server in [True, False]:
            for t in self.TYPES:
                self.set_up()
                try:
                    facade = await self._setup(
                        self._portfolio(t, server), server)
                    self._assert_extension(facade)
                    facade.close()
                except Exception as e:
                    logging.error(e, exc_info=True)
                    self.fail(e)
                self.tear_down()

    @run_async
    async def test_open(self):
        for server in [True, False]:
            for t in self.TYPES:
                self.set_up()
                try:
                    facade = await self._setup(
                        self._portfolio(t, server), server)
                    facade.close()

                    facade = await self._open()
                    self._assert_extension(facade)
                    facade.close()
                except Exception as e:
                    logging.error(e, exc_info=True)
                    self.fail(e)
                self.tear_down()
