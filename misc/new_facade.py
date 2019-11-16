# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Layout for new Facade framework."""
import inspect
from typing import Any, Union


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
                type(self.__instance).__name__, self.__decoratee.__name__))

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

    def __init__(self, facade: BaseFacade):
        """Initialize frozen base class."""
        self.__facade = facade

    @property
    def facade(self) -> BaseFacade:
        """Expose a readonly weakref of the facade.

        Returns
        -------
        Facade
            weak reference to the owning facade.

        """
        return self.__facade


class FacadeExtension(FacadeFrozen):
    """Base class for a facade service extension.

    An extension is a class or service that adds functionality to the facade,
    a kind of plugin.

    Parameters
    ----------
    facade : Facade
        Owning facade.

    """

    def __init__(self, facade: BaseFacade):
        """Initialize facade extension."""
        FacadeFrozen.__init__(self, facade)


class ApiFacadeExtension(FacadeExtension):
    """API extensions that let developers interact with the facade."""

    pass


class TaskFacadeExtension(FacadeExtension):
    """Task extension that runs as a background job in the facade."""

    pass


class ArchiveFacadeExtension(FacadeExtension):
    """Archive extension to isolate the archives."""

    pass


class FacadeMapping(FacadeFrozen):
    """Mapping of services offered by the Facade.

    Parameters
    ----------
    readonly : bool
        Makes the map reaonly.
    extensions : dict
        Dictionary of extensions to be loaded.

    """

    def __init__(
        self,
        facade: BaseFacade,
        extensions: dict=dict(),
        readonly: bool=False
    ):
        """Initialize map."""
        FacadeFrozen.__init__(self, facade)

        self.__map = extensions
        self.__readonly = readonly

    def ro(self):
        """Activate read only mechanism."""
        self.__readonly = True

    def __iter__(self):
        """Make map iteratable."""
        for k in self.__map.keys():
            yield k

    def __len__(self) -> int:
        """Add length to the map."""
        return len(self.__map)

    def __contains__(self, key: str) -> Any:
        """Add containing properties to map."""
        return key in self.__map

    def __getitem__(self, key: str):
        """Access map item."""
        return self.__map[key]

    @internal('facade')
    def __setitem__(self, key: str, value: Any):
        """Set item on the map, with internal access."""
        if not self.__readonly:
            self.__map[key] = value

    @internal('facade')
    def __delitem__(self, key: str):
        """Delete item from the map, with internal access."""
        if not self.__readonly:
            del self.__map[key]

    def __del__(self):
        """Map implicit destructor."""
        pass


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

    def __init__(self):
        """Initialize the facade."""
        self.__api = FacadeMapping(self)
        self.__task = FacadeMapping(self)
        self.__archive = FacadeMapping(self)

    @property
    def api(self) -> FacadeMapping:
        """Exposes the mapped api extensions of the facade.

        Returns
        -------
        FacadeMapping
            The mapping class for apis.

        """
        return self.__api

    @property
    def task(self) -> FacadeMapping:
        """Exposes the mapped task extensions on the facade.

        Returns
        -------
        FacadeMapping
            The mapping class for tasks.

        """
        return self.__task

    @property
    def archive(self) -> FacadeMapping:
        """Exposes the mapped archive extensions in the facade.

        Returns
        -------
        FacadeMapping
            The mapping class for archives.

        """
        return self.__archive

    @classmethod
    async def setup(
        cls,
        home_dir: str,
        secret: bytes,
        role: int,
        data: Union[EntityData, PrivatePortfolio]
    ) -> BaseFacade:
        """Set up facade from scratch."""
        pass

    @staticmethod
    async def open(home_dir: str, secret: bytes) -> BaseFacade:
        """Open existing facade from disk."""
        pass

    def close(self):
        """Close down facade."""
        pass


class EntityFacadeMixin:
    """Abstract baseclass for Entities FacadeMixin's."""

    pass


class PersonFacadeMixin(EntityFacadeMixin):
    """Mixin for a Person Facade."""

    def __init__(self):
        """Initialize facade."""
        EntityFacadeMixin.__init__(self)


class MinistryFacadeMixin(EntityFacadeMixin):
    """Mixin for a Ministry Facade."""

    def __init__(self):
        """Initialize facade."""
        EntityFacadeMixin.__init__(self)


class ChurchFacadeMixin(EntityFacadeMixin):
    """Mixin for a Church Facade."""

    def __init__(self):
        """Initialize facade."""
        EntityFacadeMixin.__init__(self)


class TypeFacadeMixin:
    """Abstract baseclass for type FacadeMixin's."""

    pass


class ServerFacadeMixin(TypeFacadeMixin):
    """Mixin for a Server Facade."""

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)


class ClientFacadeMixin(TypeFacadeMixin):
    """Mixin for a Church Facade."""

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)
