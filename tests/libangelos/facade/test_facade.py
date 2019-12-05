import os
import asyncio
import tracemalloc

from unittest import TestCase
from tempfile import TemporaryDirectory

from libangelos.const import Const
from libangelos.facade.base import BaseFacade
from libangelos.policy.portfolio import PrivatePortfolio

from libangelos.document.entities import Person, Ministry, Church
from libangelos.archive.ftp import FtpStorage
from libangelos.archive.home import HomeStorage
from libangelos.archive.mail import MailStorage
from libangelos.archive.pool import PoolStorage
from libangelos.archive.routing import RoutingStorage
from libangelos.archive.vault import VaultStorage

from libangelos.operation.setup import SetupChurchOperation, SetupPersonOperation, SetupMinistryOperation

from dummy.support import Generate


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


class TestFacade(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.server = True

    def _portfolio(self):
        return SetupPersonOperation.create(Generate.person_data()[0], server=self.server)

    def _setup(self, portfolio):
        return asyncio.run(Facade.setup(
                self.home, self.secret,
                Const.A_ROLE_PRIMARY, self.server, portfolio=portfolio
            ))

    def _open(self):
        return asyncio.run(Facade.open(self.home, self.secret))

    def tearDown(self) -> None:
        self.dir.cleanup()

    def test_setup(self):
        try:
            portfolio = self._portfolio()
            facade = self._setup(portfolio)
            facade.close()
        except Exception as e:
            self.fail(e)

    def test_open(self):
        try:
            portfolio = self._portfolio()
            facade = self._setup(portfolio)
            facade.close()

            facade = self._open()
            facade.close()
        except Exception as e:
            self.fail(e)
