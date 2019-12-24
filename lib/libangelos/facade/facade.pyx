# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""

from libangelos.api.contact import ContactAPI
from libangelos.api.mailbox import MailboxAPI
from libangelos.api.replication import ReplicationAPI
from libangelos.api.settings import SettingsAPI
from libangelos.archive.ftp import FtpStorage
from libangelos.archive.home import HomeStorage
from libangelos.archive.mail import MailStorage
from libangelos.archive.pool import PoolStorage
from libangelos.archive.routing import RoutingStorage
from libangelos.archive.vault import VaultStorage
from libangelos.const import Const
from libangelos.data.portfolio import PortfolioData
from libangelos.document.entities import Person, Ministry, Church
from libangelos.facade.base import BaseFacade
from libangelos.policy.portfolio import PrivatePortfolio

from libangelos.data.client import ClientData
from libangelos.data.prefs import PreferencesData
from libangelos.data.server import ServerData


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
    APIS = (SettingsAPI, MailboxAPI, ContactAPI, ReplicationAPI)
    DATAS = (PortfolioData, PreferencesData)
    TASKS = ()

    def __init__(self):
        """Initialize facade."""
        pass


class ServerFacadeMixin(TypeFacadeMixin):
    """Mixin for a Server Facade."""

    STORAGES = (MailStorage, PoolStorage, RoutingStorage, FtpStorage) + TypeFacadeMixin.STORAGES
    APIS = () + TypeFacadeMixin.APIS
    DATAS = (ServerData, ) + TypeFacadeMixin.DATAS
    TASKS = () + TypeFacadeMixin.TASKS

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)


class ClientFacadeMixin(TypeFacadeMixin):
    """Mixin for a Church Facade."""

    STORAGES = (HomeStorage,) + TypeFacadeMixin.STORAGES
    APIS = () + TypeFacadeMixin.APIS
    DATAS = (ClientData, ) + TypeFacadeMixin.DATAS
    TASKS = () + TypeFacadeMixin.TASKS

    def __init__(self):
        """Initialize facade."""
        TypeFacadeMixin.__init__(self)


class PersonClientFacade(BaseFacade, ClientFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity in a client."""

    INFO = (Const.A_TYPE_PERSON_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class PersonServerFacade(BaseFacade, ServerFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity as a server."""

    INFO = (Const.A_TYPE_PERSON_SERVER,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)


class MinistryClientFacade(BaseFacade, ClientFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity in a client."""

    INFO = (Const.A_TYPE_MINISTRY_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class MinistryServerFacade(BaseFacade, ServerFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity as a server."""

    INFO = (Const.A_TYPE_MINISTRY_SERVER,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)


class ChurchClientFacade(BaseFacade, ClientFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity in a client."""

    INFO = (Const.A_TYPE_CHURCH_CLIENT,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)


class ChurchServerFacade(BaseFacade, ServerFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity as a server."""

    INFO = (Const.A_TYPE_CHURCH_SERVER,)

    def __init__(self, home_dir: str, secret: bytes):
        """Initialize the facade and its mixins."""
        BaseFacade.__init__(self, home_dir, secret)
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

        vault = await VaultStorage.setup(home_dir, secret, portfolio, vault_type, vault_role)
        await vault.add_portfolio(portfolio)

        facade_class = Facade.MAP[0][vault_type]
        facade = facade_class(home_dir, secret)
        await facade.post_init(vault)
        return facade

    @staticmethod
    async def open(home_dir: str, secret: bytes) -> BaseFacade:
        """Open a facade from disk."""
        vault = VaultStorage(None, home_dir, secret)
        facade_class = Facade.MAP[0][vault.archive.stats().type]

        facade = facade_class(home_dir, secret)
        await facade.post_init(vault)
        return facade

    @classmethod
    def _check_role(cls, role: int) -> int:
        """Check that vault role is valid."""
        if role not in (Const.A_ROLE_PRIMARY, Const.A_ROLE_BACKUP):
            raise ValueError("Illegal role")
        return role

    @classmethod
    def _check_type(cls, portfolio: PrivatePortfolio, server: bool) -> None:
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