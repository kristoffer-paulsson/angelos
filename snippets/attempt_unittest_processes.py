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
from unittest import TestCase

import asyncssh
from libangelos.automatic import Automatic
from libangelos.const import Const
from libangelos.document.messages import Mail
from libangelos.facade.facade import Facade
from libangelos.ioc import ContainerAware, Handle, Container, Config
from libangelos.logger import LogHandler
from libangelos.misc import Misc
from libangelos.operation.export import ExportImportOperation
from libangelos.operation.setup import SetupChurchOperation, SetupMinistryOperation, SetupPersonOperation
from libangelos.policy.portfolio import PGroup
from libangelos.policy.types import ChurchData, MinistryData, PersonData
from libangelos.policy.verify import StatementPolicy
from libangelos.ssh.ssh import SessionManager
from libangelos.starter import Starter
from libangelos.task.task import TaskWaitress

from angelossim.support import Generate, run_async, Operations

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
                "level": "DEBUG", # INFO
                "formatter": "default",
                "filters": [],
            },
            "console": {
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stdout",
                "level": "DEBUG", # ERROR
                "formatter": "console",
                "filters": [],
            },
        },
        "loggers": {
            Const.LOG_ERR: {  # LOG_ERR is used to log system errors
                "level": "DEBUG", # INFO
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_APP: {  # LOG_APP is used to log system events
                "level": "DEBUG", # INFO
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            Const.LOG_BIZ: {  # LOG_BIZ is used to log business events
                "level": "DEBUG", # INFO
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            "asyncio": {  # 'asyncio' is used to log business events
                "level": "DEBUG", # WARNING
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
            "asyncssh": {  # 'asyncio' is used to log business events
                "level": "DEBUG",  # WARNING
                # 'propagate': None,
                "filters": [],
                "handlers": ["default"],
            },
        },
        "root": {
            "level": "DEBUG", # INFO
            "filters": [],
            "handlers": ["console", "default"],
        },
        # 'incrementel': False,
        "disable_existing_loggings": True,
    },
}


class BaseStubMixin:
    """Base stub application mixin."""

    async def initialize(self, **kwargs):
        """Initialize method is always a coroutine."""
        pass

    async def finalize(self):
        """Finalize method is always a coroutine."""
        pass


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


class BaseStubApplication(ContainerAware, BaseStubMixin):
    """Base application that is container aware."""

    def __init__(self):
        """Initialize configuration."""
        ContainerAware.__init__(self, Configuration())


class StubApplication(BaseStubApplication):
    """Facade loader and environment."""

    def __init__(self):
        """Load the facade."""
        BaseStubApplication.__init__(self)
        self.__secret = None
        self.__dir = None

    @property
    def path(self):
        """Application home directory"""
        return self.__dir.name

    @property
    def secret(self):
        """Encryption key"""
        return self.__secret

    async def initialize(self, **kwargs):
        """Setup application environment and facade."""
        self.__dir = TemporaryDirectory()
        self.__secret = Generate.new_secret()

        data = kwargs.get("entity_data")
        server = kwargs.get("type_server")

        if isinstance(data, PersonData):
            portfolio = SetupPersonOperation.create(data, server=server)
        elif isinstance(data, MinistryData):
            portfolio = SetupMinistryOperation.create(data, server=server)
        elif isinstance(data, ChurchData):
            portfolio = SetupChurchOperation.create(data, server=server)
        else:
            raise TypeError("Unknown data type, got %s" % type(data))

        self.ioc.facade = await Facade.setup(
            self.__dir.name,
            self.__secret,
            Const.A_ROLE_PRIMARY,
            server,
            portfolio=portfolio
        )

    async def finalize(self):
        """Clean up environment"""
        self.ioc.facade.close()
        self.__dir.cleanup()


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

    def __init__(self, name: str, **kwargs):
        Process.__init__(self, name=name, daemon=True)
        super(StubRunnableMixin, self).__init__()
        self.name = name
        self.__queue = JoinableQueue(maxsize=1)
        self.__result = Queue()
        self.__kwargs = kwargs

    @property
    def queue(self) -> JoinableQueue:
        """The command queue"""
        return self.__queue

    @property
    def result(self) -> Queue:
        """The result from the last task"""
        return self.__result

    async def __initialize(self):
        logging.basicConfig(stream=sys.stderr, level=self.__kwargs.get("log_level"))
        asyncssh.set_log_level(self.__kwargs.get("log_level"))
        asyncssh.set_debug_level(3)

        for cls in self.__class__.mro():
            if asyncio.iscoroutinefunction(getattr(cls, "initialize", None)):
                await cls.initialize(self, **self.__kwargs)

    async def __inner_loop(self):
        command = True
        while bool(command):
            try:
                command = self.__queue.get()
                if not command:
                    continue

                task = getattr(self, "do_" + command.task, None)

                if asyncio.iscoroutinefunction(task):
                    result = await task(*command.largs, **command.kwargs)
                else:
                    raise RuntimeError("Expected '%s' to be a coroutine" % command.task)

                if not self.__result.empty():
                    raise RuntimeError("Pending result")
                self.__result.put((command.task, result))
                self.__queue.task_done()
            except Exception as e:
                logging.error(e, exc_info=True)

    async def __finalize(self):
        for cls in self.__class__.mro():
            if asyncio.iscoroutinefunction(getattr(cls, "finalize", None)):
                await cls.finalize(self)

    async def _run(self):
        try:
            await self.__initialize()
            await self.__inner_loop()
            await self.__finalize()
        except Exception as e:
            logging.critical(e, exc_info=True)

    def run(self):
        """Execute all commands given through the queue."""
        asyncio.run(self._run())

    async def do_exit(self):
        """Exit stub task"""
        self.__queue.put(None)

    async def finalize(self):
        """Terminate the process."""
        self.__queue.close()
        self.__queue.join_thread()

        self.__result.close()
        self.__result.join_thread()


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
        print("Shall we connect?", self.name)
        cnid = uuid.UUID(self.ioc.facade.data.client["CurrentNetwork"])
        host = await self.ioc.facade.storage.vault.load_portfolio(cnid, PGroup.SHARE_MIN_COMMUNITY)
        print("Start connection", self.name)
        connection, client = await Starter().clients_client(
            self.ioc.facade.data.portfolio, host, 5 + 8000, ioc=self.ioc)
        await client.mail()


class CrossAuthMixin(BaseStubMixin):
    """Application mixin that cross authenticates and exchange mails."""

    async def do_export_portfolio(self, user: uuid.UUID = None, community: bool = True) -> str:
        """Export client portfolio data."""
        if not user:
            user = self.ioc.facade.data.portfolio.entity.id

        return ExportImportOperation.text_exp(
            await self.ioc.facade.storage.vault.load_portfolio(
                user,
                PGroup.SHARE_MAX_COMMUNITY if community else PGroup.SHARE_MAX_USER
            )
        )

    async def do_import_portfolio(self, data: str):
        """Import portfolio data."""
        await self.ioc.facade.storage.vault.add_portfolio(
            ExportImportOperation.text_imp(data))

    async def do_import_documents(self, data: str):
        """Import portfolio data."""
        portfolio = ExportImportOperation.text_imp(data)
        await self.ioc.facade.storage.vault.docs_to_portfolio(
            portfolio.owner.trusted | portfolio.owner.verified | portfolio.owner.revoked |
            portfolio.issuer.trusted | portfolio.issuer.verified | portfolio.issuer.revoked)

    async def do_trust_portfolio_save(self, user: uuid.UUID):
        """Load a portfolio to trust and save result."""
        portfolio = await self.ioc.facade.storage.vault.load_portfolio(user, PGroup.VERIFIER)
        trust = StatementPolicy.trusted(self.ioc.facade.data.portfolio, portfolio)

        await self.ioc.facade.storage.vault.docs_to_portfolio(set([trust]))

    async def do_client_set_network(self, network: uuid.UUID):
        """Index and set network."""
        await TaskWaitress().wait_for(self.ioc.facade.task.network_index)

        networks = {net[0] for net in await self.ioc.facade.api.settings.networks() if net[1]}
        if str(network) not in networks:
            return False

        self.ioc.facade.data.client["CurrentNetwork"] = network
        await Misc.sleep()
        return True

    async def do_send_mail(self, recipient: uuid.UUID) -> Mail:
        """Send a lipsum mail to recipient."""
        portfolio = await self.ioc.facade.storage.vault.load_portfolio(recipient, PGroup.VERIFIER)
        return await Operations.send_mail(self.ioc.facade, portfolio)

    async def do_receive_mail(self) -> set:
        """Check the inbox and open all new mail."""
        envelopes = await self.ioc.facade.api.mailbox.load_inbox()
        mails = set()
        for envelope in envelopes:
            mails.add(await self.facade.api.mailbox.open_envelope(envelope))
        return mails


class StubServer(StubApplication, StubRunnableMixin, ClientsServerMixin, CrossAuthMixin):
    """Stub server for simulations and testing."""

    def __init__(self, name: str, **kwargs):
        StubApplication.__init__(self)
        StubRunnableMixin.__init__(self, name, **kwargs)


class StubClient(StubApplication, StubRunnableMixin, ClientsClientMixin, CrossAuthMixin):
    """Stub client for simulations and testing."""

    def __init__(self, name: str, **kwargs):
        StubApplication.__init__(self)
        StubRunnableMixin.__init__(self, name, **kwargs)


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
        if app.name in self.__processes.keys():
            raise KeyError("Process name '%s' taken" % app.name)

        self.__processes[app.name] = app
        app.start()

    def do(self, name: str, task: str, *largs, **kwargs):
        """Tell an application to carry out a command."""
        if name not in self.__processes.keys():
            raise KeyError("Process '%s' not found" % name)

        proc = self.__processes[name]
        proc.queue.put(ApplicationCommand(task, *largs, **kwargs))
        proc.queue.join()
        done, result = proc.result.get()
        if done != task:
            raise RuntimeError("Expected result from '%s' but got from '%s'" % (task, done))
        return result

    def cleanup(self):
        """Kill and clean up all processes"""
        for proc in self.__processes:
            self.do(proc, "exit")

    def __del__(self):
        self.cleanup()


class BaseNetworkProcessTestCase(TestCase):
    pref_loglevel = logging.INFO

    @classmethod
    def setUpClass(cls) -> None:
        """Set up the network process class."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.pref_loglevel)
        asyncssh.set_log_level(cls.pref_loglevel)

    @classmethod
    def tearDownClass(cls) -> None:
        """Tear down the network process class."""
        tracemalloc.stop()

    def setup_manager(self):
        """Initialize process manager"""
        self.manager = StubManager()

    async def setup_client(self, name: str):
        """Start a new client"""
        self.manager.start(StubClient(
            name, entity_data=Generate.person_data()[0], type_server=False, log_level=self.pref_loglevel))

    async def setup_server(self, name: str):
        """Start a new server"""
        self.manager.start(StubServer(
            name, entity_data=Generate.church_data()[0], type_server=True, log_level=self.pref_loglevel))


class DemoTest(BaseNetworkProcessTestCase):
    """A test to demonstrate the process based application tester."""
    pref_loglevel = logging.DEBUG

    @run_async
    async def setUp(self) -> None:
        """Set up a single test case"""
        self.setup_manager()
        await self.setup_server("server")
        await self.setup_client("client1")
        await self.setup_client("client2")

    def tearDown(self) -> None:
        """Tear down a single test case"""
        self.manager.cleanup()
        del self.manager

    def cross_auth(self, manager: StubManager, server: str, client: str):
        client_data = manager.do(client, "export_portfolio", community=False)
        client_portfolio = ExportImportOperation.text_imp(client_data)
        manager.do(server, "import_portfolio", data=client_data)

        server_data = manager.do(server, "export_portfolio")
        server_portfolio = ExportImportOperation.text_imp(server_data)
        manager.do(client, "import_portfolio", data=server_data)

        manager.do(server, "trust_portfolio_save", user=client_portfolio.entity.id)
        client_data = manager.do(server, "export_portfolio", user=client_portfolio.entity.id, community=False)

        manager.do(client, "import_documents", data=client_data)
        manager.do(client, "trust_portfolio_save", user=server_portfolio.entity.id)
        return manager.do(client, "client_set_network", network=server_portfolio.entity.id)

    def mutual_trust(self, manager: StubManager, first: str, second: str):
        first_data = manager.do(first, "export_portfolio", community=False)
        first_portfolio = ExportImportOperation.text_imp(first_data)
        manager.do(second, "import_portfolio", data=first_data)
        manager.do(second, "trust_portfolio_save", user=first_portfolio.entity.id)

        second_data = manager.do(second, "export_portfolio", community=False)
        second_portfolio = ExportImportOperation.text_imp(second_data)
        manager.do(first, "import_portfolio", data=second_data)
        manager.do(first, "trust_portfolio_save", user=second_portfolio.entity.id)

    def send_mail(self, manager: StubManager, sender: str, receiver: str) -> Mail:
        receiver_data = manager.do(receiver, "export_portfolio", community=False)
        receiver_portfolio = ExportImportOperation.text_imp(receiver_data)

        return manager.do(sender, "send_mail", receiver_portfolio.entity.id)

    @run_async
    async def test_run(self):
        try:
            # Make the server and clients authenticated and connectable.
            print("Cross auth")
            self.assertTrue(self.cross_auth(self.manager, "server", "client1"))
            self.assertTrue(self.cross_auth(self.manager, "server", "client2"))

            print("Mutual trust")
            # Make clients mutually trust each other
            self.mutual_trust(self.manager, "client1", "client2")

            print("Send mail")
            # Write and post a mail from client1 to client2
            mail = self.send_mail(self.manager, "client1", "client2")
            self.assertIs(type(mail), Mail)

            print("Start server")
            # Start server
            # self.manager.do("server", "listen_clients")
            print("Client 1 replicate")
            # Replicate client1  outbox
            self.manager.do("client1", "connect_client")
            print("Client 2 replicate")
            # Replicate client2 inbox
            self.manager.do("client2", "connect_client")

            print("Get mail")
            # Load inbox and verify letter
            mails = self.manager.do("client2", "receive_mail")
            self.assertIn(mail, mails)
        except Exception as e:
            self.fail(e)
