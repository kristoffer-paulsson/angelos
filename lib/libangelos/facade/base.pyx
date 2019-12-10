# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Layout for new Facade framework."""
import asyncio
import logging
import os
from collections import namedtuple
from typing import Awaitable

from libangelos.policy.portfolio import PGroup
from libangelos.utils import Util


class FacadeFrozen:
    """Base class for instances owned by the Facade.

    All inheritors has a reference back to their owning Facade and can make use
    of the @internal decorator.

    Parameters
    ----------
    facade : Facade
        Owning facade instance.

    """

    def __init__(self, facade: "BaseFacade"):
        """Initialize frozen base class."""
        self.__facade = facade

    @property
    def facade(self) -> "BaseFacade":
        """Expose a readonly weakref of the facade.

        Returns
        -------
        Facade
            weak reference to the owning facade.

        """
        return self.__facade

    @facade.setter
    def facade(self, facade: "BaseFacade") -> None:
        """Set facade if not already set."""
        if not self.__facade:
            self.__facade = facade


class FacadeExtension(FacadeFrozen):
    """Base class for a facade service extension.

    An extension is a class or service that adds functionality to the facade,
    a kind of plugin.

    Parameters
    ----------
    facade : Facade
        Owning facade.

    """
    ATTRIBUTE = ("",)

    def __init__(self, facade: "BaseFacade"):
        """Initialize facade extension."""
        FacadeFrozen.__init__(self, facade)

    async def async_gather(self, *aws: Awaitable) -> bool:
        """Run multiple awaitables in asyncio.gather.

        If there is any exceptions they will be printed to the logs.

        Parameters
        ----------
        *aws : Awaitable
            Multiple awaitables to be run async.

        Returns
        -------
        bool
            Success or failure.

        """
        results = await asyncio.shield(asyncio.gather(*aws, return_exceptions=True))
        exceptions = list(filter(lambda element: isinstance(element, Exception), results))
        if exceptions:
            for exc in exceptions:
                logging.exception(exc, exc_info=True)
            return False
        else:
            return True



class BaseFacade:
    """Facade is the interface and firewall for an entity and its documents.

    Parameters
    ----------
    home_dir : str
        Path to the facade storage archives.
    secret : bytes
        32 byte encryption key.
    vault : "StorageFacadeExtension"
        The vault storage.

    Attributes
    ----------
    __home_dir : type
        Description of attribute `__home_dir`.
    __secret : type
        Description of attribute `__secret`.
    __post_init : type
        Description of attribute `__post_init`.
    __closed : type
        Description of attribute `__closed`.
    __data : type
        Description of attribute `__data`.
    __api : type
        Description of attribute `__api`.
    __task : type
        Description of attribute `__task`.
    __storage : type
        Description of attribute `__storage`.

    """
    def __init__(self, home_dir: str, secret: bytes, vault: "StorageFacadeExtension"):
        """Initialize the facade."""
        vault.facade = self

        self.__home_dir = home_dir
        self.__secret = secret
        self.__post_init = False

        self.__closed = False

        self.__data = dict()
        self.__api = dict()
        self.__task = dict()
        self.__storage = {"vault": vault}

        self._load_storages(vault.archive.stats())
        self._load_extensions("APIS", self.__api)
        self._load_extensions("DATAS", self.__data)
        self._load_extensions("TASKS", self.__task)

    def _load_extensions(self, attr: str, exts: dict) -> None:
        if hasattr(self, attr):
            for ext_cls in getattr(self, attr, []):
                extension = ext_cls(self)

                attribute = extension.ATTRIBUTE[0]
                if attribute in exts.keys():
                    raise RuntimeError(
                        "Extension attribute \"%s\" in \"%s\" already occupied." % (attribute, attr))
                exts[attribute] = extension

    def _load_storages(self, stats) -> None:
        if hasattr(self, "STORAGES"):
            for stor_cls in self.STORAGES:
                if os.path.isfile(stor_cls.filename(stor_cls.CONCEAL[0])):
                    storage = stor_cls(self, self.__home_dir, self.__secret)
                else:
                    storage = stor_cls.setup(self, self.__home_dir, self.__secret, owner=stats.owner, node=stats.node,
                                             domain=stats.domain)

                attribute = storage.ATTRIBUTE[0]
                if attribute in self.__storage.keys():
                    raise RuntimeError(
                        "Extension attribute \"%s\" in \"%s\"already occupied." % (attribute, self.__storages.__name__))
                self.__storage[attribute] = storage

    async def post_init(self) -> None:
        """Async post initialization."""
        self._check_post_init()

        self.__data = namedtuple("DataNTuple", self.__data.keys())(**self.__data)
        self.__api = namedtuple("ApiNTuple", self.__api.keys())(**self.__api)
        self.__task = namedtuple("TaskNTuple", self.__task.keys())(**self.__task)
        self.__storage = namedtuple("ArchiveNTuple", self.__storage.keys())(**self.__storage)

        portfolio = await self.storage.vault.load_portfolio(
            self.storage.vault.archive.stats().owner, PGroup.ALL)
        Util.populate(self.data.portfolio, vars(portfolio))

        self.__post_init = True

    def _check_post_init(self) -> None:
        if self.__post_init:
            raise RuntimeError("Post init already done")

    @property
    def path(self) -> str:
        """Property exposing the Facade home directory..

        Returns
        -------
        str
            Facade home path.

        """
        return self.__home_dir

    @property
    def secret(self) -> bytes:
        """Property exposing the Facade encryption key.

        Returns
        -------
        bytes
            Facade encryption key.

        """
        return self.__secret

    @property
    def closed(self) -> bool:
        """Indicate if archive is closed.

        Returns
        -------
        bool
            Facade closed state.

        """
        return self.__closed

    @property
    def data(self):
        """Exposes the data extensions of the facade.

        Returns
        -------
        FacadeMapping
            The mapping class for apis.

        """
        return self.__data

    @property
    def api(self):
        """Exposes the mapped api extensions of the facade.

        Returns
        -------
        FacadeMapping
            The mapping class for apis.

        """
        return self.__api

    @property
    def task(self):
        """Exposes the mapped task extensions on the facade.

        Returns
        -------
        FacadeMapping
            The mapping class for tasks.

        """
        return self.__task

    @property
    def storage(self):
        """Exposes the mapped archive extensions in the facade.

        Returns
        -------
        FacadeMapping
            The mapping class for archives.

        """
        return self.__storage

    def close(self) -> None:
        """Close down the facade in a proper way."""
        if not self.__closed:
            self.__closed = True
            for storage in self.__storage:
                storage.close()
