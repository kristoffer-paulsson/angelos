# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Layout for new Facade framework."""
import os
import inspect
from typing import Any, Union, Dict
from collections import namedtuple

from ..policy._types import EntityDataT
from ..policy.portfolio import PrivatePortfolio


class internal:
    """Checking external access to methods.

    internal is a decorator you put on class methods to authorize external
    access. The class applying the decorator should have an owning instance,
    and the owning instance must be available in apublicly accessible
    attribute.

    Parameters
    ----------
    decoratee : type
        Description of parameter `decoratee`.
    owner : str
        Class owner attribute name.

    """

    def __init__(self, decoratee, owner="internal"):
        """Initialize the @internal decorator."""
        self.__decoratee = decoratee
        self.__owner = owner
        self.__instance = None

    def __get__(self, instance, owner):
        """Get the instance of the owner."""
        self.__instance = instance
        return self.__call__

    def __call__(self, *args, **kwargs):
        """Access checker of decorated method."""
        stack = inspect.stack()
        caller_instance = stack[1][0].f_locals["self"]
        owner_instance = getattr(self.__instance, self.__owner, None)

        if caller_instance not in (owner_instance, self.__instance):
            raise RuntimeError("Illegal access to internal method %s.%s" % (
                self.__instance, owner_instance))

        return self.__decoratee(self.__instance, *args, **kwargs)


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


class BaseFacade:
    """Facade is the interface and firewall for an entity and its documents.

    Attributes
    ----------
    __api : type
        Description of attribute `__api`.
    __task : type
        Description of attribute `__task`.
    __archive : type
        Description of attribute `__archive`.

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

    def _load_extensions(self, attr: str, exts: dict):
        if hasattr(self, attr):
            for ext_cls in getattr(self, attr, []):
                extension = ext_cls(self)

                attribute = extension.ATTRIBUTE[0]
                if attribute in exts.keys():
                    raise RuntimeError(
                        "Extension attribute \"%s\" in \"%s\"already occupied." % (attribute, exts.__name__))
                exts[attribute] = extension

    def _load_storages(self, stats):
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

    async def post_init(self):
        """Post __init__ initialization.

        When implementing _post_init, don't forget to call:
        super().post_init(self)
        """
        if self.__post_init:
            raise RuntimeError("Post init already done")
        else:
            self.__post_init = True

        self.__data = namedtuple("DataNTuple", self.__data.keys())(**self.__data)
        self.__api = namedtuple("ApiNTuple", self.__api.keys())(**self.__api)
        self.__task = namedtuple("TaskNTuple", self.__task.keys())(**self.__task)
        self.__storage = namedtuple("ArchiveNTuple", self.__storage.keys())(**self.__storage)

    @property
    def path(self) -> str:
        """Property exposing the Facade home directory."""
        return self.__home_dir

    @property
    def secret(self) -> bytes:
        """Property exposing the Facade encryption key."""
        return self.__secret

    @property
    def closed(self):
        """Indicate if archive is closed."""
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

    def close(self):
        """Close down facade."""
        if not self.__closed:
            self.__closed = True
            for storage in self.__storage:
                storage.close()
