import asyncio
import json
import logging
import sys
import tracemalloc
import uuid
from collections import ChainMap
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

import asyncssh
from angelos.common.misc import Misc
from angelos.document.messages import Mail
from angelos.facade.facade import Facade, TaskWaitress
from angelos.lib.automatic import Automatic
from angelos.lib.const import Const
from angelos.lib.ioc import Config, Container, Handle, ContainerAware
from angelos.lib.policy.types import ChurchData, PersonData
from angelos.lib.ssh.ssh import SessionManager
from angelos.lib.starter import Starter
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.portfolio.collection import PrivatePortfolio, Portfolio
from angelos.portfolio.envelope.wrap import WrapEnvelope
from angelos.portfolio.message.create import CreateMail
from angelos.portfolio.portfolio.setup import SetupChurchPortfolio, SetupPersonPortfolio
from angelos.portfolio.statement.create import CreateTrustedStatement
from angelos.portfolio.utils import Groups


ENV_DEFAULT = {"name": "Logo"}

"""Environment immutable values."""
ENV_IMMUTABLE = {}

"""Configuration default values"""
CONFIG_DEFAULT = {
    "prefs": {
        "network": ("Preferences", "CurrentNetwork", None),
    }
}

"""Configuration immutable values"""
CONFIG_IMMUTABLE = {
    "logger": {
        "version": 1,
        "formatters": {
            "default": {
                "format": "%(asctime)s %(name)s:%(levelname)s %(message)s",
                "datefmt": "%Y-%m-%d %H:%M:%S",
            },
            "console": {"format": "%(levelname)s %(message)s"},
        },
        "filters": {"default": {"name": ""}},
        "handlers": {
            "default": {
                "class": "logging.FileHandler",
                "filename": "angelos.log",
                "mode": "a+",
                "level": "INFO",
                "formatter": "default",
                "filters": [],
            },
            "console": {
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
                "level": "ERROR",
                "formatter": "console",
                "filters": [],
            },
        },
        "loggers": {
            "asyncio": {  # 'asyncio' is used to log business events
                "level": "WARNING",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
        },
        "root": {
            "level": "INFO",
            "filters": [],
            "handlers": ["console", "default"],
        },
        # 'incrementel': False,
        "disable_existing_loggings": True,
    },
}


class Configuration(Config, Container):
    """Container configuration."""

    def __init__(self):
        Container.__init__(self, self.__config())

    def __load(self, filename):
        try:
            with open(str(Path(self.auto.dir.root, filename))) as jc:
                return json.load(jc.read())
        except FileNotFoundError:
            return {}

    def __config(self):
        return {
            "env": lambda x: ChainMap(
                ENV_IMMUTABLE,
                vars(self.auto),
                self.__load("env.json"),
                ENV_DEFAULT,
            ),
            "config": lambda x: ChainMap(
                CONFIG_IMMUTABLE, self.__load("config.json"), CONFIG_DEFAULT
            ),
            "clients": lambda x: Handle(asyncio.base_events.Server),
            "nodes": lambda x: Handle(asyncio.base_events.Server),
            "hosts": lambda x: Handle(asyncio.base_events.Server),
            "session": lambda x: SessionManager(),
            "facade": lambda x: Handle(Facade),
            "auto": lambda x: Automatic("Logo"),
        }


class StubApplication(ContainerAware):
    """Facade loader and environment."""

    def __init__(self, facade: Facade):
        """Load the facade."""
        ContainerAware.__init__(self, Configuration())
        self.ioc.facade = facade

    def stop(self):
        pass


class StubServer(StubApplication):
    """Stub server for simulations and testing."""

    STUB_SERVER = True

    async def listen(self):
        """Listen for clients."""
        self.ioc.clients = await Starter().clients_server(
            self.ioc.facade.data.portfolio,
            str(self.ioc.facade.data.portfolio.node.iploc()[0]),
            5 + 8000,
            ioc=self.ioc,
        )
        self.ioc.session.reg_server("clients", self.ioc.clients)


class StubClient(StubApplication):
    """Stub client for simulations and testing."""

    STUB_SERVER = False

    async def connect(self):
        """Connect to server."""
        cnid = uuid.UUID(self.ioc.facade.data.client["CurrentNetwork"])
        host = await self.ioc.facade.storage.vault.load_portfolio(cnid, Groups.SHARE_MIN_COMMUNITY)
        _, client = await Starter().clients_client(self.ioc.facade.data.portfolio, host, 5 + 8000, ioc=self.ioc)
        return client


class ApplicationContext:
    """Environmental context for a stub application."""

    def __init__(self, tmp_dir: TemporaryDirectory, secret: bytes, app):
        self.dir = tmp_dir
        self.secret = secret
        self.app = app

    @classmethod
    async def _setup(cls, app_cls, portfolio: PrivatePortfolio):
        """Set up stub application environment."""
        secret = Generate.new_secret()
        tmp_dir = TemporaryDirectory()

        app = app_cls(Facade(Path(tmp_dir.name), secret, portfolio, Const.A_ROLE_PRIMARY, app_cls.STUB_SERVER))
        return cls(tmp_dir, secret, app)

    def __del__(self):
        if self.app:
            self.app.stop()
        self.dir.cleanup()

    @classmethod
    async def create_server(cls) -> "ApplicationContext":
        """Create a stub server."""
        return await cls._setup(
            StubServer, SetupChurchPortfolio().perform(
                ChurchData(**Generate.church_data()[0]), server=StubServer.STUB_SERVER))

    @classmethod
    async def create_client(cls) -> "ApplicationContext":
        """Create a stub client."""
        return await cls._setup(
            StubClient, SetupPersonPortfolio().perform(
                PersonData(**Generate.person_data()[0]), server=StubClient.STUB_SERVER))


class Operations:
    """Application, facade and portfolio operations."""

    @classmethod
    async def trust_mutual(cls, f1: Facade, f2: Facade):
        """Make two facades mutually trust each other."""

        docs = set()
        docs.add(CreateTrustedStatement().perform(f1.data.portfolio, f2.data.portfolio))
        docs.add(CreateTrustedStatement().perform(f2.data.portfolio, f1.data.portfolio))

        await f1.storage.vault.accept_portfolio(f2.data.portfolio.to_portfolio())
        await f2.storage.vault.accept_portfolio(f1.data.portfolio.to_portfolio())

        await f1.storage.vault.statements_portfolio(docs)
        await f2.storage.vault.statements_portfolio(docs)

        await TaskWaitress().wait_for(f1.task.contact_sync)
        await TaskWaitress().wait_for(f2.task.contact_sync)

    @classmethod
    async def send_mail(cls, sender: Facade, recipient: Portfolio) -> Mail:
        """Generate one mail to recipient using a facade saving the mail to the outbox."""
        builder = CreateMail().perform(sender.data.portfolio, recipient)
        message = builder.message(Generate.lipsum_sentence(), Generate.lipsum().decode()).done()
        envelope = WrapEnvelope().perform(sender.data.portfolio, recipient, message)
        await sender.api.mailbox.save_outbox(envelope)
        return message


    @classmethod
    async def cross_authenticate(cls, server: Facade, client: Facade, preselect: bool = True) -> bool:
        """Cross authenticate a server and a client.

        The facade will import each others portfolios, then they will trust each other and update the portfolios.
        Also the networks will be indexed at the client and the recent network preselected.
        When the client and server are cross authenticated, the client should be able to connect to the server.

        Args:
            server (Facade):
                Facade of the server
            client (Facade):
                Facade of the client
            preselect (bool):
                If the server should be the primary network in the client facade.

        Returns (bool):
            Whether the server is successfully indexed as a trusted network

        """
        # Client --> Server
        # Export the public client portfolio
        client_data = await client.storage.vault.load_portfolio(
            client.data.portfolio.entity.id, Groups.SHARE_MAX_USER)

        # Add client portfolio to server
        await server.storage.vault.accept_portfolio(client_data)

        # Load server data from server vault
        server_data = await server.storage.vault.load_portfolio(
            server.data.portfolio.entity.id, Groups.SHARE_MAX_COMMUNITY)

        # Add server portfolio to client
        await client.storage.vault.accept_portfolio(server_data)

        # Server -" Client
        # Trust the client portfolio
        trust = CreateTrustedStatement().perform(server.data.portfolio, client.data.portfolio)

        # Saving server trust for client to server
        await server.storage.vault.statements_portfolio(set([trust]))

        # Client <-- -" Server
        # Load client data from server vault
        client_data = await server.storage.vault.load_portfolio(
            client.data.portfolio.entity.id, Groups.SHARE_MAX_USER)

        # Saving server trust for client to client
        await client.storage.vault.statements_portfolio(client_data.trusted_owner)

        # Client -" Server
        # Trust the server portfolio
        trust = CreateTrustedStatement().perform(client.data.portfolio, server.data.portfolio)

        # Saving client trust for server to client
        await client.storage.vault.statements_portfolio(set([trust]))

        # Client (index network)
        await TaskWaitress().wait_for(client.task.network_index)

        # Verify trusted network
        networks = {net[0] for net in await client.api.settings.networks() if net[1]}
        eid = str(server.data.portfolio.entity.id)
        if eid not in networks:
            raise AssertionError("%s not in networks." % str(server.data.portfolio.entity.id))

        if preselect:
            client.data.client["CurrentNetwork"] = server.data.portfolio.entity.id
            await Misc.sleep()

        return True


class TestFullReplication(TestCase):
    pref_loglevel = logging.DEBUG
    pref_connectable = True

    server = None
    client1 = None
    client2 = None

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.pref_loglevel)
        asyncssh.logging.set_log_level(cls.pref_loglevel)

    @run_async
    async def setUp(self) -> None:
        """Create client/server network nodes."""
        self.server = await ApplicationContext.create_server()
        self.client1 = await ApplicationContext.create_client()
        self.client2 = await ApplicationContext.create_client()

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.server
        del self.client1
        del self.client2

    @run_async
    async def test_mail_replication_client1_server_client2(self):
        """A complete test of two clients mailing to each other via a server."""
        # Make all players trust each other
        await Operations.cross_authenticate(self.server.app.ioc.facade, self.client1.app.ioc.facade, True)
        await Operations.cross_authenticate(self.server.app.ioc.facade, self.client2.app.ioc.facade, True)
        await Operations.trust_mutual(self.client1.app.ioc.facade, self.client2.app.ioc.facade)

        mail = await Operations.send_mail(self.client1.app.ioc.facade, self.client2.app.ioc.facade.data.portfolio)
        await self.server.app.listen()

        self.assertIs(
            len(await self.client1.app.ioc.facade.api.mailbox.load_outbox()), 1,
            "Client 1 should have one (1) letter in the outbox before connecting."
        )

        client = await self.client1.app.connect()
        await client.mail()

        self.assertIs(
            len(await self.server.app.ioc.facade.storage.mail.search()), 1,
            "Server should have one (1) letter in its routing mail box after Client 1 connected."
        )
        self.assertIs(
            len(await self.client1.app.ioc.facade.api.mailbox.load_outbox()), 0,
            "Client 1 should have zero (0) letters in its outbox after connecting to server."
        )

        client = await self.client2.app.connect()
        await client.mail()

        inbox = await self.client2.app.ioc.facade.api.mailbox.load_inbox()
        self.assertIs(
            len(inbox), 1,
            "Client 2 should have one (1) letter in its inbox after connecting to the server."
        )
        self.assertIs(
            len(await self.server.app.ioc.facade.storage.mail.search()), 0,
            "Server should have zero (0) letters in its routing mail box after Client 2 connected."
        )
        mail2 = await self.client2.app.ioc.facade.api.mailbox.open_envelope(inbox.pop())
        self.assertEqual(mail.body, mail2.body, "Checking that the sent mail equals the received mail.")