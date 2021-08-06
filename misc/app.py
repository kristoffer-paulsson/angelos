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
"""Environment default values."""
import asyncio
import collections
import json
import uuid
from tempfile import TemporaryDirectory

from angelos.common.misc import BaseData
from angelos.lib.automatic import Automatic, Path
from angelos.lib.const import Const
from angelos.facade.facade import Facade, TypeFacadeMixin, ClientFacadeMixin, ServerFacadeMixin
from angelos.lib.ioc import Handle, ContainerAware, Config, Container
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.lib.ssh.ssh import SessionManager
from angelos.lib.starter import Starter
from angelos.meta.fake import Generate
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio, SetupMinistryPortfolio, SetupChurchPortfolio
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
            "env": lambda x: collections.ChainMap(
                ENV_IMMUTABLE,
                vars(self.auto),
                self.__load("env.json"),
                ENV_DEFAULT,
            ),
            "config": lambda x: collections.ChainMap(
                CONFIG_IMMUTABLE, self.__load("config.json"), CONFIG_DEFAULT
            ),
            "clients": lambda x: Handle(asyncio.base_events.Server),
            "nodes": lambda x: Handle(asyncio.base_events.Server),
            "hosts": lambda x: Handle(asyncio.base_events.Server),
            "session": lambda x: SessionManager(),
            # "log": lambda x: LogHandler(self.config["logger"]),
            "facade": lambda x: Handle(Facade),
            "auto": lambda x: Automatic("Logo"),
        }


class StubApplication(ContainerAware):
    """Facade loader and environment."""

    def __init__(self, facade: Facade):
        """Load the facade."""
        ContainerAware.__init__(self, Configuration())
        self.ioc.facade = facade

    @classmethod
    async def open(cls, home_dir: Path, secret: bytes) -> TypeFacadeMixin:
        return Facade(home_dir, secret)

    @classmethod
    async def create(cls, home_dir: Path, secret: bytes, data: BaseData) -> TypeFacadeMixin:
        """Implement facade generation logic here."""
        if isinstance(data, PersonData):
            portfolio = SetupPersonPortfolio.perform(data, server=cls.STUB_SERVER)
        elif isinstance(data, MinistryData):
            portfolio = SetupMinistryPortfolio.perform(data, server=cls.STUB_SERVER)
        elif isinstance(data, ChurchData):
            portfolio = SetupChurchPortfolio.perform(data, server=cls.STUB_SERVER)
        else:
            raise TypeError()

        return Facade(home_dir, secret, Const.A_ROLE_PRIMARY, cls.STUB_SERVER, portfolio=portfolio)

    def stop(self):
        """Stop."""
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
    async def setup(cls, app_cls, data):
        """Set up stub application environment."""
        secret = Generate.new_secret()
        tmp_dir = TemporaryDirectory()
        print(app_cls)
        app = await app_cls.create(Path(tmp_dir.name), secret, data)
        return cls(tmp_dir, secret, app)

    def __del__(self):
        if self.app:
            self.app.stop()
        self.dir.cleanup()


class StubMaker:
    """Maker of stubs."""

    TYPES = (
        (SetupPersonPortfolio, Generate.person_data, PersonData),
        (SetupMinistryPortfolio, Generate.ministry_data, MinistryData),
        (SetupChurchPortfolio, Generate.church_data, ChurchData)
    )

    @classmethod
    async def __setup(cls, operation, generator, home: Path, secret: bytes, server: bool):
        return Facade(home, secret, Const.A_ROLE_PRIMARY, server,
            portfolio=operation.perform(generator()[0], server=server))

    @classmethod
    async def create_person_facade(cls, homedir: Path, secret: bytes, server: bool = False) -> Facade:
        """Generate random person facade.

        Args:
            homedir (str):
                The destination of the encrypted archives.
            secret (bytes):
                 Encryption key.
            server (bool):
                Generate a server of client, defaults to client.

        Returns (Facade):
            The generated facade instance.

        """
        return await cls.__setup(SetupPersonPortfolio, Generate.person_data, homedir, secret, server)

    @classmethod
    async def create_ministry_facade(cls, homedir: Path, secret: bytes, server: bool = False) -> Facade:
        """Generate random ministry facade.

        Args:
            homedir (str):
                The destination of the encrypted archives.
            secret (bytes):
                 Encryption key.
            server (bool):
                Generate a server of client, defaults to client.

        Returns (Facade):
            The generated facade instance.

        """
        return await cls.__setup(SetupMinistryPortfolio, Generate.ministry_data, homedir, secret, server)

    @classmethod
    async def create_church_facade(cls, homedir: Path, secret: bytes, server: bool = True) -> bytes:
        """Generate random church facade.

        Args:
            homedir (str):
                The destination of the encrypted archives.
            secret (bytes):
                 Encryption key.
            server (bool):
                Generate a server of client, defaults to client.

        Returns (Facade):
            The generated facade instance.

        """
        return await cls.__setup(SetupChurchPortfolio, Generate.church_data, homedir, secret, server)

    @classmethod
    async def create_server(cls) -> ApplicationContext:
        """Create a stub server."""
        return await ApplicationContext.setup(StubServer, ChurchData(**Generate.church_data()[0]))

    @classmethod
    async def create_client(cls) -> ApplicationContext:
        """Create a stub client."""
        return await ApplicationContext.setup(StubClient, PersonData(**Generate.person_data()[0]))