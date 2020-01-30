import asyncio
import collections
import json
import logging
import os
import sys
import tracemalloc
import uuid
from multiprocessing import Process, JoinableQueue, Queue
from tempfile import TemporaryDirectory
from typing import Any
from unittest import TestCase

from libangelos.automatic import Automatic
from libangelos.const import Const
from libangelos.facade.facade import ServerFacadeMixin, TypeFacadeMixin, Facade
from libangelos.ioc import ContainerAware, Handle, Container, Config
from libangelos.logger import LogHandler
from libangelos.misc import BaseDataClass, Misc
from libangelos.operation.setup import SetupChurchOperation, SetupMinistryOperation, SetupPersonOperation
from libangelos.policy.portfolio import PGroup
from libangelos.policy.types import ChurchData, MinistryData, PersonData
from libangelos.ssh.ssh import SessionManager
from libangelos.starter import Starter

from dummy.support import Generate, run_async, Operations

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
    """Application configuration."""

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


class BaseStubApplication(ContainerAware):

    def __init__(self):
        """Initialize configuration."""
        ContainerAware.__init__(self, Configuration())


class StubApplication(BaseStubApplication):
    """Facade loader and environment."""

    def __init__(self, facade: Facade, home_dir: TemporaryDirectory, secret: bytes):
        """Load the facade."""
        BaseStubApplication.__init__(self)
        self.__dir = home_dir
        self.__secret = secret
        self.ioc.facade = facade

    @property
    def path(self):
        """Application home directory"""
        return self.__dir.name

    @property
    def secret(self):
        """Encryption key"""
        return self.__secret

    @staticmethod
    async def _create(path: str, secret: bytes, data: BaseDataClass, server: bool) -> TypeFacadeMixin:
        """Implement facade generation logic here."""
        if isinstance(data, PersonData):
            portfolio = SetupPersonOperation.create(data, server=True)
        elif isinstance(data, MinistryData):
            portfolio = SetupMinistryOperation.create(data, server=True)
        elif isinstance(data, ChurchData):
            portfolio = SetupChurchOperation.create(data, server=True)
        else:
            raise TypeError("Unknown data type, got %s" % type(data))

        return await Facade.setup(
            path,
            secret,
            Const.A_ROLE_PRIMARY,
            server,
            portfolio=portfolio
        )

    @staticmethod
    async def create(name: str, data: BaseDataClass) -> ServerFacadeMixin:
        """Create application abstract function."""
        raise NotImplementedError()

    def stop(self):
        """Clean up home directory"""
        self.__dir.cleanup()


class BaseStubMixin:
    """Base stub application mixin."""


class ApplicationCommand:
    """Command that instructs a runnable to execute a task and comes with input data."""

    def __init__(self, task: str, *largs, **kwargs):
        """Initialize command

        Args:
            task (str):
                The task to be executed
            *largs (list):
                List arguments for the task
            **kwargs (dict):
                Dictionary arguments for the task
        """
        self.__task = task
        self.__largs = largs
        self.__kwargs = kwargs

    @property
    def task(self) -> str:
        """Task to be called"""
        return self.__task

    @property
    def largs(self) -> list:
        """Argument list"""
        return self.__largs

    @property
    def kwargs(self) -> dict:
        """Keyword arguments"""
        return self.__kwargs


class StubRunnableMixin(BaseStubMixin, Process):
    """Mixin to make stub application runnable."""

    def __init__(self, name: str):
        Process.__init__(self, name=name, daemon=True)
        self.__queue = JoinableQueue(maxsize=1)
        self.__result = Queue()

    @property
    def queue(self) -> JoinableQueue:
        """The command queue"""
        return self.__queue

    def result(self) -> Any:
        """The result from the last task"""
        return self.__result.get()

    def run(self):
        """Execute all commands given through the queue."""
        command = True
        while command:
            command = self.__queue.get()
            if not command:
                continue

            task = getattr(self, "do_" + command.task, None)

            if callable(task):
                try:
                    result = task(*command.largs, **command.kwargs)
                    if not self.__result.empty():
                        raise RuntimeError("Pending result")
                    self.__result.put((command.task, result))
                except Exception as e:
                    logging.critical(e, exc_info=True)
            else:
                raise AttributeError("Method do_%s doesn't exist." % command.task)

            self.__queue.task_done()

    def do_exit(self):
        """Exit stub task"""
        pass

    def stop(self):
        """Terminate the process."""
        if not self.__queue.empty():
            raise RuntimeError("Queue not empty")
        self.__queue.close()
        self.__queue.join_thread()

        if not self.__result.empty():
            raise RuntimeError("Result not empty")
        self.__result.close()
        self.__result .join_thread()

        self.terminate()


class ClientsServerMixin(BaseStubMixin):
    """Application mixin that runs a clients server."""

    async def do_listen_clients(self):
        """Runnable tasks that listen for incoming connections."""
        self.ioc.clients = await Starter().clients_server(
            self.ioc.facade.data.portfolio,
            str(Misc.iploc(self.ioc.facade.data.portfolio.node)[0]),
            5 + 8000,
            ioc=self.ioc,
        )
        self.ioc.session.reg_server("clients", self.ioc.clients)


class ClientsClientMixin(BaseStubMixin):
    """Application mixin that connects to a clients server."""

    async def do_connect_client(self):
        """Runnable task that opens a connection to a server."""
        cnid = uuid.UUID(self.ioc.facade.data.client["CurrentNetwork"])
        host = await self.ioc.facade.storage.vault.load_portfolio(cnid, PGroup.SHARE_MIN_COMMUNITY)
        _, client = await Starter().clients_client(self.ioc.facade.data.portfolio, host, 5 + 8000, ioc=self.ioc)
        return client


class StubServer(StubApplication, StubRunnableMixin, ClientsServerMixin):
    """Stub server for simulations and testing."""

    def __init__(self, name: str, facade: Facade, home_dir: TemporaryDirectory, secret: bytes):
        StubApplication.__init__(self, facade, home_dir, secret)
        StubRunnableMixin.__init__(self, name)

    @classmethod
    async def create(cls, name: str, data: BaseDataClass) -> ServerFacadeMixin:
        """Create a new stub server."""
        home_dir = TemporaryDirectory()
        secret = Generate.new_secret()
        return cls(name, await StubApplication._create(home_dir.name, secret, data, True), home_dir, secret)

    def stop(self):
        """Clean up server"""
        StubRunnableMixin.stop(self)
        StubApplication.stop(self)


class StubClient(StubApplication, StubRunnableMixin, ClientsClientMixin):
    """Stub client for simulations and testing."""

    def __init__(self, name: str, facade: Facade, home_dir: TemporaryDirectory, secret: bytes):
        StubApplication.__init__(self, facade, home_dir, secret)
        StubRunnableMixin.__init__(self, name)

    @classmethod
    async def create(cls, name: str, data: BaseDataClass) -> ServerFacadeMixin:
        """Create a new client"""
        home_dir = TemporaryDirectory()
        secret = Generate.new_secret()
        return cls(name, await StubApplication._create(home_dir.name, secret, data, False), home_dir, secret)

    def stop(self):
        """Clean up client"""
        StubRunnableMixin.stop(self)
        StubApplication.stop(self)


class StubManager:
    """Manager for several application processes."""

    def __init__(self):
        self.__processes = dict()

    @property
    def proc(self):
        """Dictionary of processes"""
        return self.__processes

    def start(self, app: StubRunnableMixin):
        """Start a process for a new application."""
        if app.name in self.__processes:
            raise KeyError("Process name taken")

        self.__processes[app.name] = app
        app.start()

    def do(self, name: str, task: str, *largs, **kwargs):
        """Tell an application to carry out a command."""
        if name not in self.__processes:
            raise KeyError("Process name taken")

        proc = self.__processes[name]
        proc.queue.put(ApplicationCommand(task, *largs, **kwargs))
        proc.queue.join()
        done, result = proc.result()
        if done != task:
            raise RuntimeError("Expected result from '%s' but got from '%s'" % (task, done))
        return result


    def cleanup(self):
        """Kill and clean up all processes"""
        for proc in self.__processes.values():
            proc.stop()

    def __del__(self):
        self.cleanup()


class BaseNetworkProcessTestCase(TestCase):
    pref_loglevel = logging.ERROR

    @classmethod
    def setUpClass(cls) -> None:
        """Set up the network process class."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.pref_loglevel)

    @classmethod
    def tearDownClass(cls) -> None:
        """Tear down the network process class."""
        tracemalloc.stop()

    def setup_manager(self):
        """Initialize process manager"""
        self.manager = StubManager()

    async def setup_client(self, name: str):
        """Start a new client"""
        self.manager.start(await StubClient.create(name, Generate.person_data()[0]))

    async def setup_server(self, name: str):
        """Start a new server"""
        self.manager.start(await StubServer.create(name, Generate.church_data()[0]))

    @run_async
    async def setUp(self) -> None:
        """Set up a single test case"""
        self.setup_manager()
        await self.setup_server("server")
        await self.setup_client("client1")
        await self.setup_client("client2")

    def tearDown(self) -> None:
        """Tear down a single test case"""
        del self.manager


class DemoTest(BaseNetworkProcessTestCase):
    """A test to demonstrate the process based application tester."""
    pref_loglevel = logging.DEBUG

    @run_async
    async def test_run(self):
        try:
            # Make the server and clients authenticated and connectable.
            self.assertTrue(
                await Operations.cross_authenticate(
                    self.manager.proc["server"].ioc.facade,
                    self.manager.proc["client1"].ioc.facade
                )
            )
            self.assertTrue(
                await Operations.cross_authenticate(
                    self.manager.proc["server"].ioc.facade,
                    self.manager.proc["client2"].ioc.facade
                )
            )

            self.manager.do("server", "exit")
            self.manager.do("client1", "exit")
            self.manager.do("client2", "exit")
        except Exception as e:
            self.fail(e)
