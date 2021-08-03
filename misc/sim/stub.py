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
"""Stub classes for dummy and unit testing."""
import asyncio

import collections
import json
import os
import uuid

from angelos.common.automatic import Automatic
from angelos.common.const import Const
from angelos.common.facade.facade import Facade, TypeFacadeMixin, ClientFacadeMixin, ServerFacadeMixin
from angelos.common.ioc import ContainerAware, Config, Container, Handle
from libangelos.logger import LogHandler
from angelos.common.misc import BaseDataClass, Misc
from angelos.common.operation.setup import SetupChurchOperation, SetupMinistryOperation, SetupPersonOperation
from angelos.common.policy.portfolio import PGroup
from angelos.common.policy.types import PersonData, MinistryData, ChurchData
from angelos.common.reactive import Event
from angelos.common.reactive import NotifierMixin, ObserverMixin
from angelos.common.ssh.ssh import SessionManager
from angelos.common.starter import Starter


class StubNotifier(NotifierMixin):
    """Stub notifier."""
    pass


class StubObserver(ObserverMixin):
    """Stub observer."""
    event = None

    async def notify(self, event: Event):
        self.event = event


"""Environment default values."""
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
            Const.LOG_ERR: {  # LOG_ERR is used to log system errors
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_APP: {  # LOG_APP is used to log system events
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_BIZ: {  # LOG_BIZ is used to log business events
                "level": "INFO",
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
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
    def __init__(self):
        Container.__init__(self, self.__config())

    def __load(self, filename):
        try:
            with open(os.path.join(self.auto.dir.root, filename)) as jc:
                return json.load(jc.read())
        except FileNotFoundError:
            return {}

    def __config(self):
        return {
            "env": lambda self: collections.ChainMap(
                ENV_IMMUTABLE,
                vars(self.auto),
                self.__load("env.json"),
                ENV_DEFAULT,
            ),
            "config": lambda self: collections.ChainMap(
                CONFIG_IMMUTABLE, self.__load("config.json"), CONFIG_DEFAULT
            ),
            "clients": lambda self: Handle(asyncio.base_events.Server),
            "nodes": lambda self: Handle(asyncio.base_events.Server),
            "hosts": lambda self: Handle(asyncio.base_events.Server),
            "session": lambda self: SessionManager(),
            "log": lambda self: LogHandler(self.config["logger"]),
            "facade": lambda self: Handle(Facade),
            "auto": lambda self: Automatic("Logo"),
        }


class BaseApplicationStub(ContainerAware):

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
        raise NotImplementedError()

    @staticmethod
    async def create(home_dir: str, secret: bytes, data: BaseDataClass) -> ServerFacadeMixin:
        raise NotImplementedError()

    def stop(self):
        pass


class StubServer(StubApplication):
    """Stub server for simulations and testing."""

    @staticmethod
    async def open(home_dir: str, secret: bytes) -> ServerFacadeMixin:
        return StubServer(await StubApplication._open(home_dir, secret))

    @staticmethod
    async def create(home_dir: str, secret: bytes, data: BaseDataClass) -> ServerFacadeMixin:
        return StubServer(await StubApplication._create(home_dir, secret, data, True))

    async def listen(self):
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
        return StubClient(await StubApplication._open(home_dir, secret))

    @staticmethod
    async def create(home_dir: str, secret: bytes, data: BaseDataClass) -> ClientFacadeMixin:
        return StubClient(await StubApplication._create(home_dir, secret, data, False))

    async def connect(self):
        cnid = uuid.UUID(self.ioc.facade.data.client["CurrentNetwork"])
        host = await self.ioc.facade.storage.vault.load_portfolio(cnid, PGroup.SHARE_MIN_COMMUNITY)
        _, client = await Starter().clients_client(self.ioc.facade.data.portfolio, host, 5 + 8000, ioc=self.ioc)
        return client
