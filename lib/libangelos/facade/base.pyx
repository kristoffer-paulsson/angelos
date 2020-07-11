# cython: language_level=3
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
"""Layout for new Facade framework."""
import asyncio
import logging
import os
from typing import Awaitable

from libangelos.error import ContainerServiceNotConfigured
from libangelos.ioc import Container
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

    async def gather(self, *aws: Awaitable) -> bool:
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
        awaitable = asyncio.gather(*aws, return_exceptions=True)
        await asyncio.sleep(0)
        results = await awaitable
        exceptions = list(filter(lambda element: isinstance(element, Exception), results))
        if exceptions:
            for exc in exceptions:
                logging.error(exc, exc_info=True)
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
    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade."""

        self.__home_dir = home_dir
        self.__secret = secret
        self.__post_init = False

        self.__closed = False

        self.__storage = None
        self.__api = self.__load_extensions("APIS")
        self.__data = self.__load_extensions("DATAS")
        self.__task = self.__load_extensions("TASKS")

    def __load_extensions(self, attr: str) -> Container:
        """Prepare facade extensions in an ioc container.

        Args:
            attr (str):
                The attribute name to look for class type.

        Returns:
            Initiated ioc Container.

        """
        def generator(klass, facade):
            """Container lambda generator."""
            return lambda x: klass(facade)

        if hasattr(self, attr):
            config = dict()

            for ext_cls in getattr(self, attr, []):
                attribute = ext_cls.ATTRIBUTE[0]
                if attribute in config.keys():
                    raise RuntimeError(
                        "Extension attribute \"%s\" in \"%s\" already occupied." % (attribute, attr))
                config[attribute] = generator(ext_cls, self)

            return Container(config)
        else:
            return None

    async def __load_storages(self, vault: "StorageFacadeExtension") -> Container:
        """Prepare facade storage extensions in an ioc container.

        Args:
            vault (StorageFacadeExtension):
                Already instantiated VaultStorage.

        Returns:
            Initiated ioc Container.

        """
        def generator(klass, facade, path, secret):
            """Container lambda generator."""
            return lambda x: klass(facade, path, secret)

        def generator_setup(instance):
            """Container lambda generator."""
            return lambda x: instance

        if hasattr(self, "STORAGES"):
            config = {"vault": lambda x: vault}
            stats = vault.archive.stats()

            for storage_cls in self.STORAGES:
                attribute = storage_cls.ATTRIBUTE[0]
                if attribute in config.keys():
                    raise RuntimeError(
                        "Extension attribute \"%s\" in \"%s\"already occupied." % (attribute, self.__storages.__name__))

                if os.path.isfile(storage_cls.filename(self.__home_dir)):
                    config[attribute] = generator(storage_cls, self, self.__home_dir, self.__secret)
                else:
                    storage = await storage_cls.setup(
                        self, self.__home_dir, self.__secret, owner=stats.owner,  node=stats.node, domain=stats.domain)
                    await asyncio.sleep(0)

                    config[attribute] = generator_setup(storage)

            return Container(config)
        else:
            return None

    async def post_init(self, vault: "VaultStorage") -> None:
        """Async post initialization."""
        self._check_post_init()

        vault.facade = self
        self.__storage = await self.__load_storages(vault)

        portfolio = await self.storage.vault.load_portfolio(
            self.storage.vault.archive.stats().owner, PGroup.ALL)
        Util.populate(self.data.portfolio, vars(portfolio))

        await self.api.settings.load_preferences()
        self.data.prefs.post_init()

        try:
            self.data.server.post_init()
        except ContainerServiceNotConfigured as e:
            pass

        try:
            self.data.client.post_init()
        except ContainerServiceNotConfigured as e:
            pass

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
