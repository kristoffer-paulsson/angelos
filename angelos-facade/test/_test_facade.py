import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.document.domain import Node
from angelos.document.entities import Person, Ministry, Church
from angelos.document.types import PersonData, MinistryData, ChurchData
from angelos.facade.api.contact import ContactAPI
from angelos.facade.api.crud import CrudAPI
from angelos.facade.api.mailbox import MailboxAPI
from angelos.facade.api.replication import ReplicationAPI
from angelos.facade.api.settings import SettingsAPI
from angelos.facade.data.client import ClientData
from angelos.facade.data.portfolio import PortfolioData
from angelos.facade.data.prefs import PreferencesData
from angelos.facade.data.server import ServerData
from angelos.facade.facade import Facade, PersonClientFacade, PersonServerFacade, MinistryClientFacade, \
    MinistryServerFacade, ChurchClientFacade, ChurchServerFacade, Path, StorageFacadeExtension, DataFacadeExtension, \
    ApiFacadeExtension, TaskFacadeExtension
from angelos.facade.storage.ftp import FtpStorage
from angelos.facade.storage.home import HomeStorage
from angelos.facade.storage.mail import MailStorage
from angelos.facade.storage.pool import PoolStorage
from angelos.facade.storage.routing import RoutingStorage
from angelos.facade.storage.vault import VaultStorage
from angelos.facade.task.contact_sync import ContactPortfolioSyncTask
from angelos.facade.task.network_index import NetworkIndexerTask
from angelos.lib.const import Const
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio, SetupMinistryPortfolio, SetupChurchPortfolio


class TestFacade(TestCase):

    @classmethod
    def setUpClass(cls) -> None:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = Path(self.dir.name)

    def tearDown(self) -> None:
        self.dir.cleanup()

    def services_client(self, facade):
        self.assertIsInstance(facade.storage.vault, VaultStorage)
        self.assertTrue(self.home.joinpath(VaultStorage.CONCEAL[0]).is_file())
        self.assertIsInstance(facade.storage.home, HomeStorage)
        self.assertTrue(self.home.joinpath(HomeStorage.CONCEAL[0]).is_file())
        self.assertIsInstance(facade.data.client, ClientData)
        self.assertIsInstance(facade.data.portfolio, PortfolioData)
        self.assertIsInstance(facade.data.prefs, PreferencesData)
        self.assertIsInstance(facade.api.settings, SettingsAPI)
        self.assertIsInstance(facade.api.mailbox, MailboxAPI)
        self.assertIsInstance(facade.api.contact, ContactAPI)
        self.assertIsInstance(facade.api.replication, ReplicationAPI)
        self.assertIsInstance(facade.task.contact_sync, ContactPortfolioSyncTask)
        self.assertIsInstance(facade.task.network_index, NetworkIndexerTask)

    def services_server(self, facade):
        self.assertIsInstance(facade.storage.vault, VaultStorage)
        self.assertTrue(self.home.joinpath(VaultStorage.CONCEAL[0]).is_file())
        self.assertIsInstance(facade.storage.mail, MailStorage)
        self.assertTrue(self.home.joinpath(MailStorage.CONCEAL[0]).is_file())
        self.assertIsInstance(facade.storage.pool, PoolStorage)
        self.assertTrue(self.home.joinpath(PoolStorage.CONCEAL[0]).is_file())
        self.assertIsInstance(facade.storage.routing, RoutingStorage)
        self.assertTrue(self.home.joinpath(RoutingStorage.CONCEAL[0]).is_file())
        self.assertIsInstance(facade.storage.ftp, FtpStorage)
        self.assertTrue(self.home.joinpath(FtpStorage.CONCEAL[0]).is_file())
        self.assertIsInstance(facade.data.server, ServerData)
        self.assertIsInstance(facade.data.portfolio, PortfolioData)
        self.assertIsInstance(facade.data.prefs, PreferencesData)
        # self.assertIsInstance(facade.api.crud, CrudAPI)
        self.assertIsInstance(facade.api.settings, SettingsAPI)
        self.assertIsInstance(facade.api.mailbox, MailboxAPI)
        self.assertIsInstance(facade.api.contact, ContactAPI)
        self.assertIsInstance(facade.api.replication, ReplicationAPI)
        self.assertIsInstance(facade.task.contact_sync, ContactPortfolioSyncTask)
        self.assertIsInstance(facade.task.network_index, NetworkIndexerTask)

    def extension_type(self, facade):
        self.assertIs(facade.storage.facade, facade)
        for ext in facade.storage:
            self.assertIsInstance(ext, StorageFacadeExtension)
            self.assertIs(ext.facade, facade)

        self.assertIs(facade.data.facade, facade)
        for ext in facade.data:
            self.assertIsInstance(ext, DataFacadeExtension)
            self.assertIs(ext.facade, facade)

        self.assertIs(facade.api.facade, facade)
        for ext in facade.api:
            self.assertIsInstance(ext, ApiFacadeExtension)
            self.assertIs(ext.facade, facade)

        self.assertIs(facade.task.facade, facade)
        for ext in facade.task:
            self.assertIsInstance(ext, TaskFacadeExtension)
            self.assertIs(ext.facade, facade)


class TestPersonClientFacade(TestFacade):
    @run_async
    async def test_facade(self):
        facade = Facade(self.home, self.secret,
            SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=False
        )
        self.services_client(facade)
        self.assertIsInstance(facade, PersonClientFacade)
        self.assertIsInstance(facade.data.portfolio.entity, Person)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()

        facade = Facade(self.home, self.secret)
        self.assertIsInstance(facade.data.portfolio.entity, Person)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()


class TestPersonServerFacade(TestFacade):
    @run_async
    async def test_facade(self):
        facade = Facade(self.home, self.secret,
            SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=True
        )
        self.services_server(facade)
        self.assertIsInstance(facade, PersonServerFacade)
        self.assertIsInstance(facade.data.portfolio.entity, Person)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()

        facade = Facade(self.home, self.secret)
        self.assertIsInstance(facade.data.portfolio.entity, Person)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()


class TestMinistryClientFacade(TestFacade):
    @run_async
    async def test_facade(self):
        facade = Facade(self.home, self.secret,
            SetupMinistryPortfolio().perform(MinistryData(**Generate.ministry_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=False
        )
        self.services_client(facade)
        self.assertIsInstance(facade, MinistryClientFacade)
        self.assertIsInstance(facade.data.portfolio.entity, Ministry)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()

        facade = Facade(self.home, self.secret)
        self.assertIsInstance(facade.data.portfolio.entity, Ministry)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()


class TestMinistryServerFacade(TestFacade):
    @run_async
    async def test_facade(self):
        facade = Facade(self.home, self.secret,
            SetupMinistryPortfolio().perform(MinistryData(**Generate.ministry_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=True
        )
        self.services_server(facade)
        self.assertIsInstance(facade, MinistryServerFacade)
        self.assertIsInstance(facade.data.portfolio.entity, Ministry)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()

        facade = Facade(self.home, self.secret)
        self.assertIsInstance(facade.data.portfolio.entity, Ministry)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()


class TestChurchClientFacade(TestFacade):
    @run_async
    async def test_facade(self):
        facade = Facade(self.home, self.secret,
            SetupChurchPortfolio().perform(ChurchData(**Generate.church_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=False
        )
        self.services_client(facade)
        self.assertIsInstance(facade, ChurchClientFacade)
        self.assertIsInstance(facade.data.portfolio.entity, Church)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()

        facade = Facade(self.home, self.secret)
        self.assertIsInstance(facade.data.portfolio.entity, Church)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()


class TestChurchServerFacade(TestFacade):
    @run_async
    async def test_facade(self):
        facade = Facade(self.home, self.secret,
            SetupChurchPortfolio().perform(ChurchData(**Generate.church_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=True
        )
        self.services_server(facade)
        self.assertIsInstance(facade, ChurchServerFacade)
        self.assertIsInstance(facade.data.portfolio.entity, Church)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()

        facade = Facade(self.home, self.secret)
        self.assertIsInstance(facade.data.portfolio.entity, Church)
        self.assertIsInstance(facade.data.portfolio.node, Node)
        self.extension_type(facade)
        facade.close()
