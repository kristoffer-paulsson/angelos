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
import os
import uuid
from tempfile import TemporaryDirectory

from angelos.common.misc import BaseDataClass
from angelos.lib.automatic import Automatic, Path
from angelos.lib.const import Const
from angelos.lib.facade.facade import Facade, TypeFacadeMixin, ClientFacadeMixin, ServerFacadeMixin
from angelos.lib.ioc import Handle, ContainerAware, Config, Container
from angelos.lib.operation.setup import SetupPersonOperation, SetupMinistryOperation, SetupChurchOperation
from angelos.lib.policy.portfolio import PGroup
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.lib.ssh.ssh import SessionManager
from angelos.lib.starter import Starter
from angelos.meta.fake import Generate

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


class BaseApplicationStub(ContainerAware):
    """Application stub base class."""

    def __init__(self):
        """Initialize configuration."""
        ContainerAware.__init__(self, Configuration())


class StubApplication(BaseApplicationStub):
    """Facade loader and environment."""

    def __init__(self, facade: Facade):
        """Load the facade."""
        BaseApplicationStub.__init__(self)
        self.ioc.facade = facade

    @staticmethod
    async def _open(home_dir: str, secret: bytes) -> TypeFacadeMixin:
        return await Facade.open(home_dir, secret)

    @staticmethod
    async def _create(home_dir: str, secret: bytes, data: BaseDataClass, server: bool) -> TypeFacadeMixin:
        """Implement facade generation logic here."""
        if isinstance(data, PersonData):
            portfolio = SetupPersonOperation.create(data, server=True)
        elif isinstance(data, MinistryData):
            portfolio = SetupMinistryOperation.create(data, server=True)
        elif isinstance(data, ChurchData):
            portfolio = SetupChurchOperation.create(data, server=True)
        else:
            raise RuntimeError()

        return await Facade.setup(
            home_dir,
            secret,
            Const.A_ROLE_PRIMARY,
            server,
            portfolio=portfolio
        )

    @staticmethod
    async def open(home_dir: str, secret: bytes) -> ClientFacadeMixin:
        """Facade open abstract method."""
        raise NotImplementedError()

    @staticmethod
    async def create(home_dir: str, secret: bytes, data: BaseDataClass) -> ServerFacadeMixin:
        """Facade create abstract method."""
        raise NotImplementedError()

    def stop(self):
        """Stop."""
        pass


class StubServer(StubApplication):
    """Stub server for simulations and testing."""

    @staticmethod
    async def open(home_dir: str, secret: bytes) -> ServerFacadeMixin:
        """Open stub server."""
        return StubServer(await StubApplication._open(home_dir, secret))

    @staticmethod
    async def create(home_dir: str, secret: bytes, data: BaseDataClass) -> ServerFacadeMixin:
        """Create stub server."""
        return StubServer(await StubApplication._create(home_dir, secret, data, True))

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

    @staticmethod
    async def open(home_dir: str, secret: bytes) -> ClientFacadeMixin:
        """Open stub client."""
        return StubClient(await StubApplication._open(home_dir, secret))

    @staticmethod
    async def create(home_dir: str, secret: bytes, data: BaseDataClass) -> ClientFacadeMixin:
        """Create stub client."""
        return StubClient(await StubApplication._create(home_dir, secret, data, False))

    async def connect(self):
        """Connect to server."""
        cnid = uuid.UUID(self.ioc.facade.data.client["CurrentNetwork"])
        host = await self.ioc.facade.storage.vault.load_portfolio(cnid, PGroup.SHARE_MIN_COMMUNITY)
        _, client = await Starter().clients_client(self.ioc.facade.data.portfolio, host, 5 + 8000, ioc=self.ioc)
        return client


class ApplicationContext:
    """Environmental context for a stub application."""

    #app = None
    #dir = None
    #secret = None

    def __init__(self, tmp_dir, secret, app):
        self.dir = tmp_dir
        self.secret = secret
        self.app = app

    @classmethod
    async def setup(cls, app_cls, data):
        """Set up stub application environment."""
        secret = Generate.new_secret()
        tmp_dir = TemporaryDirectory()
        app = await app_cls.create(tmp_dir.name, secret, data)
        return cls(tmp_dir, secret, app)

    def __del__(self):
        if self.app:
            self.app.stop()
        self.dir.cleanup()


class StubMaker:
    """Maker of stubs."""

    TYPES = (
        (SetupPersonOperation, Generate.person_data, PersonData),
        (SetupMinistryOperation, Generate.ministry_data, MinistryData),
        (SetupChurchOperation, Generate.church_data, ChurchData)
    )

    @classmethod
    async def __setup(cls, operation, generator, home, secret, server):
        return await Facade.setup(
            home,
            secret,
            Const.A_ROLE_PRIMARY,
            server,
            portfolio=operation.create(
                generator()[0],
                server=server)
        )

    @classmethod
    async def create_person_facace(cls, homedir: str, secret: bytes, server: bool = False) -> Facade:
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
        return await cls.__setup(
            SetupPersonOperation, Generate.person_data, homedir, secret, server)

    @classmethod
    async def create_ministry_facade(cls, homedir: str, secret: bytes, server: bool = False) -> Facade:
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
        return await cls.__setup(
            SetupMinistryOperation, Generate.ministry_data, homedir, secret, server)

    @classmethod
    async def create_church_facade(cls, homedir: str, secret: bytes, server: bool = True) -> bytes:
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
        return await cls.__setup(
            SetupChurchOperation, Generate.church_data, homedir, secret, server)

    @classmethod
    async def create_server(cls) -> ApplicationContext:
        """Create a stub server."""
        return await ApplicationContext.setup(StubServer, ChurchData(**Generate.church_data()[0]))

    @classmethod
    async def create_client(cls) -> ApplicationContext:
        """Create a stub client."""
        return await ApplicationContext.setup(StubClient, PersonData(**Generate.person_data()[0]))