# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""

from ..api.contact import ContactAPI
from ..api.mail import MailAPI
from ..api.settings import SettingsAPI
from ..api.replication import ReplicationAPI
from ..archive.ftp import FtpStorage
from ..archive.home import HomeStorage
from ..archive.mail import MailStorage
from ..archive.pool import PoolStorage
from ..archive.routing import RoutingStorage
from ..archive.vault import VaultStorage
from ..const import Const

from ..document.entities import Person, Ministry, Church
from ..policy.portfolio import (
    PrivatePortfolio, PGroup)

from ..data.vars import PREFERENCES_INI
from .base import BaseFacade


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

    STORAGES = ()
    APIS = ()
    DATAS = ()
    TASKS = ()

    def __init__(self):
        """Initialize facade."""
        pass


class ServerFacadeMixin(TypeFacadeMixin):
    """Mixin for a Server Facade."""

    STORAGES = (MailStorage, PoolStorage, RoutingStorage, FtpStorage) + TypeFacadeMixin.STORAGES
    APIS = () + TypeFacadeMixin.APIS
    DATAS = () + TypeFacadeMixin.DATAS
    TASKS = () + TypeFacadeMixin.TASKS

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)


class ClientFacadeMixin(TypeFacadeMixin):
    """Mixin for a Church Facade."""

    STORAGES = (HomeStorage,) + TypeFacadeMixin.STORAGES
    APIS = () + TypeFacadeMixin.APIS
    DATAS = () + TypeFacadeMixin.DATAS
    TASKS = () + TypeFacadeMixin.TASKS

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)


class PersonClientFacade(BaseFacade, ClientFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity in a client."""

    INFO = (Const.A_TYPE_PERSON_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes, vault: VaultStorage):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class PersonServerFacade(BaseFacade, ServerFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity as a server."""

    INFO = (Const.A_TYPE_PERSON_SERVER,)

    def __init__(self, home_dir: str, secret: bytes, vault: VaultStorage):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class MinistryClientFacade(BaseFacade, ClientFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity in a client."""

    INFO = (Const.A_TYPE_MINISTRY_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes, vault: VaultStorage):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class MinistryServerFacade(BaseFacade, ServerFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity as a server."""

    INFO = (Const.A_TYPE_MINISTRY_SERVER,)

    def __init__(self, home_dir: str, secret: bytes, vault: VaultStorage):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class ChurchClientFacade(BaseFacade, ClientFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity in a client."""

    INFO = (Const.A_TYPE_CHURCH_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes, vault: VaultStorage):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class ChurchServerFacade(BaseFacade, ServerFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity as a server."""

    INFO = (Const.A_TYPE_CHURCH_SERVER,)

    def __init__(self, home_dir: str, secret: bytes, vault: VaultStorage):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class Facade:
    """
    Facade baseclass.

    The Facade is the gatekeeper of the integrity. The facade guarantees the
    integrity of the entity and its domain. It is here where all policies are
    enforced and where security is checked. No document can be imported without
    being verified.
    """

    MAP = ({
        Const.A_TYPE_PERSON_CLIENT: PersonClientFacade,
        Const.A_TYPE_PERSON_SERVER: PersonServerFacade,
        Const.A_TYPE_MINISTRY_CLIENT: MinistryClientFacade,
        Const.A_TYPE_MINISTRY_SERVER: MinistryServerFacade,
        Const.A_TYPE_CHURCH_CLIENT: ChurchClientFacade,
        Const.A_TYPE_CHURCH_SERVER: ChurchServerFacade,
    }, )

    @staticmethod
    async def setup(
            home_dir: str,
            secret: bytes,
            role: int,
            server: bool,
            portfolio: PrivatePortfolio
    ) -> BaseFacade:
        """Set up facade from scratch."""
        vault_role = Facade._check_role(role)
        vault_type = Facade._check_type(portfolio, server)

        vault = VaultStorage.setup(home_dir, secret, portfolio, vault_type, vault_role)
        await vault.new_portfolio(portfolio)

        facade_class = Facade.MAP[0][vault_type]
        facade = facade_class(home_dir, secret, vault)
        await facade.post_init()
        return facade

    @staticmethod
    async def open(home_dir: str, secret: bytes) -> BaseFacade:
        """Open a facade from disk."""
        vault = VaultStorage(None, home_dir, secret)
        facade_class = Facade.MAP[0][vault.archive.stats().type]

        facade = facade_class(home_dir, secret, vault)
        await facade.post_init()
        return facade

    @classmethod
    def _check_role(cls, role):
        """Check that vault role is valid."""
        if role not in (Const.A_ROLE_PRIMARY, Const.A_ROLE_BACKUP):
            raise ValueError("Illegal role")
        return role

    @classmethod
    def _check_type(cls, portfolio: PrivatePortfolio, server: bool):
        """Check that entity type is valid and calculate vault type."""
        if not portfolio.entity:
            raise ValueError("No entity present in portfolio")

        entity_type = type(portfolio.entity)
        if entity_type is Person:
            return Const.A_TYPE_PERSON_SERVER if server else Const.A_TYPE_PERSON_CLIENT
        elif entity_type is Ministry:
            return Const.A_TYPE_MINISTRY_SERVER if server else Const.A_TYPE_MINISTRY_CLIENT
        elif entity_type is Church:
            return Const.A_TYPE_CHURCH_SERVER if server else Const.A_TYPE_CHURCH_CLIENT
        else:
            raise TypeError("Entity in portfolio of unknown type")


class OldFacade(BaseFacade):


        # await vault.save_settings("preferences.ini", PREFERENCES_INI)

    async def _post_init(self):
        """Load private portfolio for facade."""
        server = (
            True
            if self._vault.stats.type
            in (
                Const.A_TYPE_PERSON_SERVER,
                Const.A_TYPE_MINISTRY_SERVER,
                Const.A_TYPE_CHURCH_SERVER,
            )
            else False
        )

        self.__portfolio = await self._vault.load_portfolio(
            self._vault.stats.owner, PGroup.SERVER if server else PGroup.CLIENT
        )
        self.__contact = ContactAPI(self.__portfolio, self._vault)
        self.__mail = MailAPI(self.__portfolio, self._vault)
        self.__settings = SettingsAPI(self.__portfolio, self._vault)
        self.__replication = ReplicationAPI(self)

    @property
    def portfolio(self):
        """Private portfolio getter."""
        return self.__portfolio

    @property
    def contact(self):
        """Contact interface getter."""
        return self.__contact

    @property
    def mail(self):
        """Mail interface getter."""
        return self.__mail

    @property
    def settings(self):
        """Settings interface getter."""
        return self.__settings

    @property
    def replication(self):
        """Replication interface getter."""
        return self.__replication