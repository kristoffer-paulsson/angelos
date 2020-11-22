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
import asyncio
import atexit
import io
import logging
import math
import time
import traceback
import uuid
import datetime
from pathlib import Path, PurePosixPath
from typing import Tuple, Awaitable, List, Any

from angelos.archive7.archive import Archive7
from angelos.archive7.fs import Delete
from angelos.common.misc import Loop, Misc
from angelos.common.utils import Util
from angelos.document.entities import Person, Ministry, Church
from angelos.lib.const import Const
from angelos.lib.reactive import NotifierMixin, ObserverMixin, Event
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.utils import Groups


class FacadeError(RuntimeError):
    """Thrown when error happens in or with a Facade."""
    EXTENSION_ATTR_OCCUPIED = ("Extension attribute already occupied.", 100)
    EXTENSION_ATTR_OCCUPIED_STORAGE = ("Extension storage attribute already occupied.", 101)
    POST_INIT_DONE = ("Post init already done", 102)
    ILLEGAL_ROLE = ("Illegal role", 103)
    MISSING_ENTITY = ("No entity present in portfolio", 104)
    UNKNOWN_ENTITY_TYPE = ("Entity in portfolio of unknown type", 105)
    EXTENSION_NOT_FOUND = ("Facade extension not found within namespace.", 106)
    EXTENSION_NO_TUPLE = ("Expected a tuple configuration.", 107)
    EXTENSION_ATTR_MISMATCH = ("The attribute and name didn't match.", "108")


class FacadeFrozen:
    """Base class for instances owned by the Facade.

    All inheritors has a reference back to their owning Facade and can make use
    of the @internal decorator.
    """

    def __init__(self, facade: "Facade"):
        """Initialize frozen base class."""
        self.__facade = facade

    @property
    def facade(self) -> "Facade":
        """Expose a readonly weakref of the facade."""
        return self.__facade

    @facade.setter
    def facade(self, facade: "Facade") -> None:
        """Set facade if not already set."""
        if not self.__facade:
            self.__facade = facade


class FacadeExtension(FacadeFrozen):
    """Base class for a facade service extension.

    An extension is a class or service that adds functionality to the facade,
    a kind of plugin.
    """

    ATTRIBUTE = ("",)

    def __init__(self, facade: "Facade"):
        """Initialize facade extension."""
        FacadeFrozen.__init__(self, facade)

    async def gather(self, *aws: Awaitable) -> List[Any]:
        """Run multiple awaitables in asyncio.gather."""
        awaitable = asyncio.gather(*aws)
        await asyncio.sleep(0)
        return await awaitable


class StorageFacadeExtension(FacadeExtension):
    """Archive extension to isolate the archives."""

    ATTRIBUTE = ("",)
    CONCEAL = ("",)
    USEFLAG = (0,)

    INIT_HIERARCHY = ()
    INIT_FILES = ()

    def __init__(self, facade: "Facade", home_dir: Path, secret: bytes, delete=Delete.HARD):
        """Initialize the Storage extension."""
        FacadeExtension.__init__(self, facade)
        self.__archive = Archive7.open(self.filename(home_dir), secret, delete)
        atexit.register(self.__archive.close)
        self.__closed = False

    @property
    def archive(self):
        """Property access to underlying storage."""
        return self.__archive

    @property
    def closed(self) -> bool:
        """Indicate if archive is closed."""
        return self.__closed

    def close(self):
        """Close the Archive."""
        if not self.__closed:
            atexit.unregister(self.__archive.close)
            self.__archive.close()
            self.__closed = True

    @classmethod
    async def setup(cls, facade: "Facade", home_dir: Path, secret: bytes,
        owner: uuid.UUID, node: uuid.UUID, domain: uuid.UUID, vault_type=None, vault_role=None,
    ):
        """Create and setup the whole Vault according to policy's."""
        archive = Archive7.setup(
            cls.filename(home_dir), secret, owner=owner, node=node, domain=domain,
            title=cls.ATTRIBUTE[0], type_=vault_type, role=vault_role, use=cls.USEFLAG[0]
        )
        await cls._hierarchy(archive)
        await cls._files(archive)
        archive.close()

        return cls(facade, home_dir, secret)

    @classmethod
    def filename(cls, dir_name: Path) -> Path:
        """"""
        return dir_name.joinpath(cls.CONCEAL[0])

    @classmethod
    async def _hierarchy(cls, archive):
        """"""
        for i in cls.INIT_HIERARCHY:
            await archive.mkdir(PurePosixPath(i))

    @classmethod
    async def _files(cls, archive):
        """"""
        for i in cls.INIT_FILES:
            await archive.mkfile(PurePosixPath(i[0]), i[1])


class ApiFacadeExtension(FacadeExtension):
    """API extensions that let developers interact with the facade."""

    def __init__(self, facade: "Facade"):
        """Initialize the Mail."""
        FacadeExtension.__init__(self, facade)


class DataFacadeExtension(FacadeExtension):
    """Archive extension to isolate the archives."""

    def __init__(self, facade: "Facade"):
        FacadeExtension.__init__(self, facade)


class TaskFacadeExtension(FacadeExtension, NotifierMixin):
    """Task extension that runs as a background job in the facade."""

    INVOKABLE = (False,)
    SCHEDULABLE = (False,)
    PERIODIC = (False,)

    ACTION_START = 1
    ACTION_COMPLETE = 2
    ACTION_CRASH = 3
    ACTION_PROGRESS = 4

    def __init__(self, facade: "Facade"):
        """Initialize the task."""
        FacadeExtension.__init__(self, facade)
        NotifierMixin.__init__(self)

        self.__loop = Misc.get_loop()
        self.__running = False
        self.__task = None
        self.__handle = None
        self.__period = None
        self.__period_start = None
        self.__timer = None
        self.__time_start = None
        self.__time_end = None

    @property
    def running(self):
        """Property exposing running state."""
        return self.__running

    def invoke(self) -> bool:
        """Invoke the task directly.

        Returns True if invocation went through. If invoking isn't available returns False."""
        if self.INVOKABLE[0]:
            self.__handle = self.__loop.call_soon(self.__launch)
            return True
        return False

    def schedule(self, when: datetime.datetime) -> bool:
        """Schedule a one-time execution of the task.

        Tell when you want the task to be executed. Returns false if task scheduling isn't available."""
        if self.SCHEDULABLE[0]:
            delay = (when - datetime.datetime.now()).total_seconds()
            self.__timer = self.__loop.call_later(delay, self.__launch)
            return True
        return False

    def periodic(self, period: datetime.timedelta, origin: datetime.datetime = datetime.datetime.now()) -> bool:
        """Execute task periodically until canceled.

        Tell the period between executions and from when to count the start. Returns false if periodic execution isn't
        available."""
        if self.PERIODIC[0]:
            self.__period = period.total_seconds()
            self.__period_start = origin.timestamp()
            self.__next_run()
            return True
        return False

    def cancel(self) -> None:
        """Cancel a scheduled or periodic pending execution."""
        if self.__handle:
            self.__handle.cancel()

        self.__period = None
        self.__period_start = None

    def __next_run(self) -> None:
        """Prepare and set next periodical execution."""
        moment = datetime.datetime.now().timestamp()
        uptime = moment - self.__period_start
        cycles = uptime / self.__period
        full_cycle = math.ceil(cycles) * self.__period
        run_in = full_cycle - uptime
        when = self.__loop.time() + run_in
        self.__timer = self.__loop.call_at(when, self.__launch)

    def __start(self) -> bool:
        """Standard preparations before execution."""
        self.__time_end = 0
        self.__running = True
        self.notify_all(self.ACTION_START, {"name": self.ATTRIBUTE[0]})
        self.__time_start = time.monotonic_ns()
        return True

    def __end(self) -> None:
        """Standard cleanup after execution."""
        self.__time_end = time.monotonic_ns()
        self.notify_all(self.ACTION_COMPLETE, {"name": self.ATTRIBUTE[0]})
        self.__running = False
        if self.__period:
            self.__next_run()

    def _progress(self, progress: float=0):
        """Notify observers made progress."""
        self.notify_all(self.ACTION_PROGRESS, {"name": self.ATTRIBUTE[0], "progress": progress})

    async def _run(self) -> None:
        """Actual task logic to be implemented here."""
        raise NotImplementedError()

    async def _initialize(self) -> None:
        """Custom initialization before task execution."""
        pass

    async def _finalize(self) -> None:
        """Custom cleanup after task execution."""
        pass

    def __launch(self) -> bool:
        """Task launcher and exception logic."""
        if self.__running:
            return False

        self.__task = self.__loop.create_task(self.__exe())
        self.__task.add_done_callback(self.__done)

    def __done(self, task):
        exc = task.exception()
        if exc:
            Util.log_exception(exc)
            self.notify_all(self.ACTION_CRASH, {
                "name": self.ATTRIBUTE[0], "task": self.__task, "exception": exc})
        else:
            logging.info("Task \"%s\" finished execution" % self.ATTRIBUTE[0])

    async def __exe(self) -> None:
        """Task executor that prepares, executes and finalizes."""
        self.__start()
        await self._initialize()
        await self._run()
        await self._finalize()
        self.__end()


class TaskWaitress(ObserverMixin):
    """Observer that lets you wait for a facade extension task."""
    def __init__(self):
        ObserverMixin.__init__(self)
        self.__waitress = asyncio.Event()

    async def notify(self, event: Event) -> None:
        """Receive action-complete event."""
        if event.action == TaskFacadeExtension.ACTION_COMPLETE:
            self.__waitress.set()

    async def wait(self) -> None:
        """Halt execution and wait for event to happen."""
        self.__waitress.clear()
        await self.__waitress.wait()

    async def wait_for(self, notifier: NotifierMixin) -> None:
        """Subscribe to, invoke, and wait for notifier."""
        notifier.subscribe(self)
        self.__waitress.clear()
        notifier.invoke()
        await self.__waitress.wait()


class FacadeNamespace(FacadeFrozen):
    """Namespace for facade extensions."""

    def __init__(self, facade: "Facade", config: dict, instances: dict = dict()):
        FacadeFrozen.__init__(self, facade)
        self.__config = config
        self.__instances = instances

    def __getattr__(self, name: str) -> FacadeExtension:
        if name not in self.__instances:
            if name not in self.__config:
                raise FacadeError(*FacadeError.EXTENSION_NOT_FOUND)
            elif isinstance(self.__config[name], tuple):
                self.__instances[name] = Util.klass(*self.__config[name])(self.facade)
            else:
                raise FacadeError(*FacadeError.EXTENSION_NO_TUPLE)
        return self.__instances[name]

    def __iter__(self):
        for instance in self.__instances.values():
            yield instance


class FacadeMeta(type):
    """"""

    def __call__(
            cls, home_dir: Path, secret: bytes,
            portfolio: PrivatePortfolio = None, role: int = None, server: bool = None
    ):
        if isinstance(portfolio, type(None)) and isinstance(role, type(None)) and isinstance(server, type(None)):
            vault, portfolio, vault_type = cls._open(home_dir, secret)
        elif portfolio is not None and role is not None and server is not None:
            vault_role = cls._check_role(role)
            vault_type = cls._check_type(portfolio, server)
            vault = cls._setup(home_dir, secret, portfolio, vault_type, vault_role)
        else:
            raise ValueError("portfolio, role and server must all be None or set.")

        self = cls.__new__(cls, vault_type)
        self.__init__(home_dir, secret, portfolio, vault)
        return self


class Facade(metaclass=FacadeMeta):
    """"""

    def __new__(cls, vault_type: int):
        """"""
        return super().__new__(CLASS_MAP[vault_type])

    def __init__(self, home_dir: Path, secret: bytes, portfolio: PrivatePortfolio, vault: "VaultStorage"):
        """"""
        self.__home_dir = home_dir
        self.__secret = secret
        self.__closed = False

        vault.facade = self
        header = vault.archive.stats()
        storages = {"vault": vault}
        for name, pkg in self.STORAGES.items():
            storage_cls = Util.klass(*pkg)
            if name != storage_cls.ATTRIBUTE[0]:
                raise FacadeError(*FacadeError.EXTENSION_ATTRIBUTE_MISMATCH)
            if home_dir.joinpath(storage_cls.CONCEAL[0]).is_file():
                storages[name] = storage_cls(self, home_dir, secret)
            else:
                storages[name] = Loop.main().run(storage_cls.setup(
                    self, home_dir, secret,
                    owner=header.owner, node=header.node, domain=header.domain,
                    vault_type=header.type, vault_role=header.role
                ), wait=True)

        portfolio = Util.klass("angelos.facade.data.portfolio", "PortfolioData")(portfolio.documents())
        portfolio.facade = self
        datas = {"portfolio": portfolio}

        self.__storage = FacadeNamespace(self, self.STORAGES, storages)
        self.__api = FacadeNamespace(self, self.APIS)
        self.__data = FacadeNamespace(self, self.DATAS, datas)
        self.__task = FacadeNamespace(self, self.TASKS)

    @property
    def path(self) -> Path:
        """Property exposing the Facade home directory."""
        return self.__home_dir

    @property
    def secret(self) -> bytes:
        """Property exposing the Facade encryption key."""
        return self.__secret

    @property
    def closed(self) -> bool:
        """Indicate if archive is closed."""
        return self.__closed

    @property
    def data(self) -> FacadeNamespace:
        """Exposes the data extensions of the facade."""
        return self.__data

    @property
    def api(self) -> FacadeNamespace:
        """Exposes the mapped api extensions of the facade."""
        return self.__api

    @property
    def task(self) -> FacadeNamespace:
        """Exposes the mapped task extensions on the facade."""
        return self.__task

    @property
    def storage(self) -> FacadeNamespace:
        """Exposes the mapped archive extensions in the facade."""
        return self.__storage

    def close(self) -> None:
        """Close down the facade in a proper way."""
        if not self.__closed:
            self.__closed = True
            for storage in self.__storage:
                storage.close()

    @classmethod
    def _setup(
            cls, home_dir: Path, secret: bytes, portfolio: PrivatePortfolio,
            vault_type: int, vault_role: int) -> "VaultStorage":
        """"""
        vault_cls = Util.klass("angelos.facade.storage.vault", "VaultStorage")
        vault = Loop.main().run(vault_cls.setup(home_dir, secret, portfolio, vault_type, vault_role), wait=True)
        Loop.main().run(vault.accept_portfolio(portfolio), wait=True)

        return vault

    @classmethod
    def _open(cls, home_dir: Path, secret: bytes) -> Tuple["VaultStorage", PrivatePortfolio, bytes]:
        """"""
        vault_cls = Util.klass("angelos.facade.storage.vault", "VaultStorage")
        vault = vault_cls(None, home_dir, secret)
        stats = vault.archive.stats()
        portfolio = Loop.main().run(vault.load_portfolio(stats.owner, Groups.ALL), wait=True)

        return vault, portfolio, stats.type

    @classmethod
    def _check_role(cls, role: int) -> int:
        """Check that vault role is valid."""
        if role not in (Const.A_ROLE_PRIMARY, Const.A_ROLE_BACKUP):
            raise FacadeError(*FacadeError.ILLEGAL_ROLE)
        return role

    @classmethod
    def _check_type(cls, portfolio: PrivatePortfolio, server: bool) -> None:
        """Check that entity type is valid and calculate vault type."""
        if not portfolio.entity:
            raise FacadeError(*FacadeError.MISSING_ENTITY)

        entity_type = type(portfolio.entity)
        if entity_type is Person:
            return Const.A_TYPE_PERSON_SERVER if server else Const.A_TYPE_PERSON_CLIENT
        elif entity_type is Ministry:
            return Const.A_TYPE_MINISTRY_SERVER if server else Const.A_TYPE_MINISTRY_CLIENT
        elif entity_type is Church:
            return Const.A_TYPE_CHURCH_SERVER if server else Const.A_TYPE_CHURCH_CLIENT
        else:
            raise FacadeError(*FacadeError.UNKNOWN_ENTITY_TYPE)


class EntityFacadeMixin:
    """Abstract baseclass for Entities FacadeMixin's."""


class PersonFacadeMixin(EntityFacadeMixin):
    """Mixin for a Person Facade."""


class MinistryFacadeMixin(EntityFacadeMixin):
    """Mixin for a Ministry Facade."""


class ChurchFacadeMixin(EntityFacadeMixin):
    """Mixin for a Church Facade."""


class TypeFacadeMixin:
    """Abstract baseclass for type FacadeMixin's."""

    STORAGES = dict()
    APIS = {
        "settings": ("angelos.facade.api.settings", "SettingsAPI"),
        "mailbox": ("angelos.facade.api.mailbox", "MailboxAPI"),
        "contact": ("angelos.facade.api.contact", "ContactAPI"),
        "replication": ("angelos.facade.api.replication", "ReplicationAPI")
    }
    DATAS = {
        "portfolio": ("angelos.facade.data.portfolio", "PortfolioData"),
        "prefs": ("angelos.facade.data.prefs", "PreferencesData")
    }
    TASKS = {
        "contact_sync": ("angelos.facade.task.contact_sync", "ContactPortfolioSyncTask"),
        "network_index": ("angelos.facade.task.network_index", "NetworkIndexerTask")
    }


class ServerFacadeMixin(TypeFacadeMixin):
    """Mixin for a Server Facade."""

    STORAGES = {
        "mail": ("angelos.facade.storage.mail", "MailStorage"),
        "pool": ("angelos.facade.storage.pool", "PoolStorage"),
        "routing": ("angelos.facade.storage.routing", "RoutingStorage"),
        "ftp": ("angelos.facade.storage.ftp", "FtpStorage"),
        **TypeFacadeMixin.STORAGES
    }
    APIS = {
        "crud": ("angelos.facade.api.crud", "CrudAPI"),
        **TypeFacadeMixin.APIS
    }
    DATAS = {
        "server": ("angelos.facade.data.server", "ServerData"),
        **TypeFacadeMixin.DATAS
    }
    TASKS = TypeFacadeMixin.TASKS


class ClientFacadeMixin(TypeFacadeMixin):
    """Mixin for a Church Facade."""

    STORAGES = {
        "home": ("angelos.facade.storage.home", "HomeStorage"),
        **TypeFacadeMixin.STORAGES
    }
    APIS = TypeFacadeMixin.APIS
    DATAS = {
        "client": ("angelos.facade.data.client", "ClientData"),
        **TypeFacadeMixin.DATAS
    }
    TASKS = TypeFacadeMixin.TASKS


class PersonClientFacade(Facade, ClientFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity in a client."""


class PersonServerFacade(Facade, ServerFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity as a server."""


class MinistryClientFacade(Facade, ClientFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity in a client."""


class MinistryServerFacade(Facade, ServerFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity as a server."""


class ChurchClientFacade(Facade, ClientFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity in a client."""


class ChurchServerFacade(Facade, ServerFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity as a server."""


CLASS_MAP = {
    Const.A_TYPE_PERSON_CLIENT: PersonClientFacade,
    Const.A_TYPE_PERSON_SERVER: PersonServerFacade,
    Const.A_TYPE_MINISTRY_CLIENT: MinistryClientFacade,
    Const.A_TYPE_MINISTRY_SERVER: MinistryServerFacade,
    Const.A_TYPE_CHURCH_CLIENT: ChurchClientFacade,
    Const.A_TYPE_CHURCH_SERVER: ChurchServerFacade,
}