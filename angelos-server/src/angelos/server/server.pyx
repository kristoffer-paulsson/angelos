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
"""Module docstring."""
import asyncio
import base64
import errno
import functools
import json
import logging
import os
import platform
import signal
import socket
import sys
from argparse import ArgumentParser
from asyncio import Task
from collections import namedtuple, ChainMap
from pathlib import PurePath, Path
from typing import Any, Coroutine

from angelos.base.app import Application, Extension
from angelos.base.ext import Quit, Signal, Arguments, Logger
from angelos.bin.nacl import Signer
from angelos.common.misc import Misc
from angelos.common.utils import Event, Util
from angelos.facade.facade import Facade
from angelos.lib.automatic import Automatic, Platform, Runtime, Server as ServerDirs, Network
from angelos.lib.const import Const
from angelos.lib.ioc import Container, Config, StaticHandle, LogAware
from angelos.lib.ssh.ssh import SessionManager
from angelos.net.base import Protocol, Packet
from angelos.psi.keyloader import KeyLoader, KeyLoadError
from angelos.psi.unique import UniqueIdentifier
from angelos.server.logger import Logger as Logga
from angelos.server.network import ServerProtocolFile, Connections
from angelos.server.parser import Parser
from angelos.server.support import ServerFacade
from angelos.server.vars import ENV_DEFAULT, ENV_IMMUTABLE, CONFIG_DEFAULT, CONFIG_IMMUTABLE


class Auto(Automatic, Platform, Runtime, ServerDirs, Network):
    def __init__(self, name: str, parser=None):
        Automatic.__init__(self, name)
        Platform.__init__(self)
        Runtime.__init__(self)
        ServerDirs.__init__(self)
        Network.__init__(self)

        self.override(parser)


class AdminKeys:
    """Load and list admin keys."""

    def __init__(self, env: ChainMap):
        self.__path_admin = os.path.join(str(env["state_dir"]), "admins.pub")
        self.__path_server = os.path.join(str(env["state_dir"]), "server")
        self.__key_list = None
        self.__key_private = None

    @property
    def key_admin(self) -> str:
        """Expose path to key-file."""
        return self.__path_admin

    @property
    def key_server(self) -> str:
        """Expose path to key-file."""
        return self.__path_server

    def load(self):
        """Load admin keys."""
        with open(self.__path_admin) as f:
            self.__key_list = [base64.b64decode(x) for x in f.readlines()]

        if not os.path.isfile(self.__path_server):
            print("Private key missing, generate new.")
            self.__key_private = base64.b64encode(Signer().seed)
            with open(self.__path_server, "w+") as f:
                f.writelines([self.__key_private])
        else:
            with open(self.__path_server) as f:
                self.__key_private = base64.b64decode(f.readline().strip())

    def list(self) -> list:
        """List admin keys."""
        return self.__key_list

    def server(self) -> Any:
        """Server private key."""
        return self.__key_private


class Bootstrap:
    """Bootstraps the server checks that all criteria match."""
    def __init__(self, env: ChainMap, keys: AdminKeys):
        self.__critical = False
        self.__env = env
        self.__keys = keys

    def __error(self, message: str):
        """Print a message to screen and in logs."""
        print(message)
        self.__critical = True

    def criteria_state(self):
        """Check that the root folder exists."""
        state_dir = self.__env["state_dir"]

        if not os.path.isdir(state_dir):
            self.__error("No state directory. ({})".format(state_dir))
            return

        if not os.access(state_dir, os.W_OK):
            self.__error("State directory not writable. ({})".format(state_dir))
            return

    def criteria_conf(self):
        """Check that the root folder exists."""
        conf_dir = self.__env["conf_dir"]

        if not os.path.isdir(conf_dir):
            self.__error("No configuration directory. ({})".format(conf_dir))
            return

        if not os.access(conf_dir, os.W_OK):
            self.__error("Configuration directory not writable. ({})".format(conf_dir))
            return

    def criteria_admin(self):
        """Check that there are public keys for admin."""
        admin_keys_file = self.__keys.key_admin

        if not os.path.isfile(admin_keys_file):
            self.__error("No admin public keys file. ({})".format(admin_keys_file))
            return

        if not os.stat(admin_keys_file).st_size:
            self.__error("Admin public keys file is empty. ({})".format(admin_keys_file))
            return

    def criteria_load_keys(self):
        """Load admin public keys into """
        try:
            self.__keys.load()
            if not self.__keys.list():
                self.__error("Failed to load admin public keys.")
                return
        except FileNotFoundError:
            pass

    def criteria_port_access(self):
        """Try to listen to designated port."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.bind(("127.0.0.1", self.__env["port"]))
            s.listen(1)
            s.close()
        except PermissionError:
            self.__error("Permission denied to use port {}.".format(self.__env["port"]))
        except socket.error as e:
            if e.errno == errno.EADDRINUSE:
                self.__error("Address with port {} already in use.".format(self.__env["port"]))
        else:
            s.close()

    def match(self) -> bool:
        """Match all criteria for proceeding operations."""

        self.criteria_state()
        self.criteria_conf()
        self.criteria_admin()
        self.criteria_load_keys()
        self.criteria_port_access()

        if self.__critical:
            print("One or several bootstrap criteria failed!", "Exit")
            return False
        else:
            return True


class Configuration(Config, Container):
    def __init__(self):
        Container.__init__(self, self.__config())

    def __load(self, filename):
        try:
            with open(os.path.join(self.auto.conf_dir, filename)) as jc:
                return json.load(jc)
        except FileNotFoundError as exc:
            print("Configuration file not found ({})".format(filename))
            # Util.print_exception(exc)
            return {}

    def __config(self):
        return {
            "env": lambda self: ChainMap(
                ENV_IMMUTABLE,
                {key: value for key, value in vars(self.opts).items() if value},
                self.__load("env.json"),
                vars(self.auto),
                ENV_DEFAULT,
            ),
            "config": lambda self: ChainMap(
                CONFIG_IMMUTABLE,
                self.__load("config.json"),
                CONFIG_DEFAULT
            ),
            "bootstrap": lambda self: Bootstrap(self.env, self.keys),
            "keys": lambda self: AdminKeys(self.env),
            "log": lambda self: Logga(self.facade.secret, self.env["logs_dir"]),
            "session": lambda self: SessionManager(),
            "facade": lambda self: StaticHandle(Facade),
            "opts": lambda self: Parser(),
            "auto": lambda self: Auto("Angelos", self.opts),
            "quit": lambda self: Event(),
        }


class Server(LogAware):
    """Main server application class."""

    def __init__(self):
        """Initialize app logger."""
        self._return_code = 0
        self._connections = None
        self._server = None
        self._server_task = None
        LogAware.__init__(self, Configuration())

    @property
    def return_code(self) -> int:
        """Server return code."""
        return self._return_code

    def create_task(self, coro: Coroutine) -> Task:
        """Create a task that reports error."""
        task = asyncio.get_event_loop().create_task(coro)
        def done(fut):
            fut.result()
        task.add_done_callback(done)
        return task

    async def start(self):
        """Start serving."""
        self._connections = Connections(self.ioc)
        self._server = await ServerProtocolFile.listen(
            ServerFacade.setup(Signer(self.ioc.keys.server())),
            self._listen(), self.ioc.env["port"], self._connections
        )
        self._server_task = self.create_task(self._server.serve_forever())

    async def stop(self):
        """Wait for quit to stop serving."""
        await self.ioc.quit.wait()
        self._server.close()
        await self._server.wait_closed()

    def _initialize(self):
        if not self.ioc.bootstrap.match():
            self._return_code = 2
            raise KeyboardInterrupt()
        logging.basicConfig(
            filename="angelos.log",
            level=logging.DEBUG,
            format="%(relativeCreated)6d %(threadName)s %(message)s"
        )
        loop = asyncio.get_event_loop()
        loop.add_signal_handler(
            signal.SIGINT, functools.partial(self.quiter, signal.SIGINT)
        )
        loop.add_signal_handler(
            signal.SIGTERM, functools.partial(self.quiter, signal.SIGTERM)
        )

        self.create_task(self.start())
        self.create_task(self.stop())

        self.normal("Starting boot server.")

    def _finalize(self):
        self.normal("Exiting server.")

    def _listen(self):
        la = self.ioc.env["listen"]
        if la == "localhost":
            listen = "localhost"
        elif la == "loopback":
            listen = "127.0.0.1"
        elif la == "hostname":
            listen = self.ioc.env["hostname"]
        elif la == "domain":
            listen = self.ioc.env["domain"]
        elif la == "ip":
            listen = self.ioc.env["ip"]
        elif la == "any":
            listen = ""
        else:
            listen = la
        return listen

    def quiter(self, signame):
        """
        Callback that trigger quit on SIGINT and SIGTERM.

        When a signal occur this handler sets the quit event
        and raises a KeyboardInterrupt
        """
        self.ioc.quit.set()
        raise KeyboardInterrupt(signame)

    def run(self):
        """Run the server applications main loop."""
        if self.ioc.env["config"]:
            self.config()
            return

        self._initialize()
        try:
            asyncio.get_event_loop().run_forever()
        except KeyboardInterrupt:
            pass
        except Exception as exc:
            self._return_code = 3
            Util.print_exception(exc)
        self._finalize()

    def config(self):
        """Print or do other works on configuration."""
        print(Util.headline("Environment (BEGIN)"))
        print("\n".join(Misc.recurse_env(self.ioc.env)))
        print(Util.headline("Environment (END)"))


class BootConfigurator(Extension):

    def criteria_state(self, config: ChainMap):
        """Check that the root folder exists."""
        state_dir = config.get("state_dir", "")

        if not os.path.isdir(state_dir):
            logging.info("No state directory. ({})".format(state_dir))
            return True

        if not os.access(state_dir, os.W_OK):
            logging.info("State directory not writable. ({})".format(state_dir))
            return True

    def criteria_conf(self, config: ChainMap):
        """Check that the root folder exists."""
        conf_dir = config.get("conf_dir", "")

        if not os.path.isdir(conf_dir):
            logging.info("No configuration directory. ({})".format(conf_dir))
            return True

        if not os.access(conf_dir, os.W_OK):
            logging.info("Configuration directory not writable. ({})".format(conf_dir))
            return True

    def criteria_admin_keys(self, config: ChainMap):
        """Check that there are keys for admin."""
        admins = config.get("admins", list())

        if not(len(admins)):
            logging.info("No admin public keys.")
            return True

    def criteria_public_key(self, config: ChainMap):
        """Check that """
        public = config.get("public", None)

        if not public:
            logging.info("No server public key.")
            return True

    def criteria_port_access(self, config: ChainMap):
        """Try to listen to designated port."""
        failure = False
        port = config.get("port", 0)
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            s.bind(("127.0.0.1", port))
            s.listen(1)
            s.close()
        except PermissionError:
            logging.info("Permission denied to use port {}.".format(port))
            failure = True
        except socket.error as e:
            if e.errno == errno.EADDRINUSE:
                logging.info("Address with port {} already in use.".format(port))
                failure = True
        else:
            s.close()

        return failure

    def args(self) -> dict:
        try:
            return {key: value for key, value in vars(self._app.args).items() if value is not None}
        except NameError:
            return dict()

    def prepare(self, *args):
        """Boot and configure everything related to program."""
        default = self._args.get("default", dict())
        keys = set(default.keys())
        bootleg = namedtuple("Bootleg", keys)

        config = ChainMap(default)
        config.maps.insert(0, self._app.sys)  # Platform information
        config.maps.insert(0, self._app.dirs)  # Automatic directories
        config.maps.insert(0, self.args())  # Program CLI arguments

        if any([
            self.criteria_state(config),
            self.criteria_conf(config),
            self.criteria_admin_keys(config),
            self.criteria_public_key(config),
            self.criteria_port_access(config)
        ]):
            pass

        return bootleg(**{key: value for key, value in config.items() if key in keys})


class System(Extension):
    """Collect information about the system."""

    def prepare(self, *args):
        """Map all system, platform and network properties."""
        hostname = socket.gethostname()
        system, node, _, _, machine, processor = platform.uname()
        return {
            "hostname": hostname.lower(),
            "ip": Misc.ip()[0],
            "domain": socket.getfqdn(),
            "user": os.environ["USER"],
            "pid": os.getpid(),
            "ppid": os.getppid(),
            "cpus": os.cpu_count(),
            "platform": sys.platform,
            "id": UniqueIdentifier.get(),
            "system": system,
            "node": node,
            "machine": machine,
            "processor": processor,
        }


class Runtime(Extension):
    """Decide program folders."""

    def prepare(self, *args):
        desktop = self._args.get("desktop", True)
        name = self._args.get("name", None)
        user = self._app.sys.get("user", "Unknown")

        if sys.platform.startswith("darwin"):
            app = name.capitalize()

            if desktop:
                root_dir = Path("/")
                run_dir = None
                state_dir = Path("~/Library/Application Support/{app}".format(app=app)).home()
                logs_dir = Path("~/Library/Logs/{app}".format(app=app)).home()
                conf_dir = Path("~/Library/Caches/{app}".format(app=app)).home()

            else:
                root_dir = Path("/")
                run_dir = None
                state_dir = Path("/Library/Application Support/{app}".format(app=app))
                logs_dir = Path("/Library/Application Support/{app}/Logs".format(app=app))
                conf_dir = Path("/Library/Application Support/{app}".format(app=app))

        elif sys.platform.startswith("win32"):
            app = name.capitalize()

            if desktop:
                root_dir = Path("C:/")
                run_dir = None
                state_dir = Path("C:/Users/{user}/AppData/Local/{author}/{app}".format(user=user, app=app, author=app))
                logs_dir = Path("C:/Users/{user}/AppData/Local/{author}/{app}/Logs".format(user=user, app=app, author=app))
                conf_dir = Path("C:/Users/{user}/AppData/Local/{author}/{app}".format(user=user, app=app, author=app))

            else:
                root_dir = Path("C:/")
                run_dir = None
                state_dir = Path("C:/ProgramData/{author}/{app}".format(app=app, author=app))
                logs_dir = Path("C:/ProgramData/{author}/{app}/Logs".format(app=app, author=app))
                conf_dir = Path("C:/ProgramData/{author}/{app}".format(app=app, author=app))

        else:
            app = name.lower()

            if desktop:
                root_dir = Path("/")
                run_dir = Path(os.environ["XDG_RUNTIME_DIR"]).home()
                state_dir = Path(os.environ["XDG_STATE_HOME"] or "~/.local/state/{app}".format(app=app)).home()
                logs_dir = Path(os.environ["XDG_CACHE_HOME"] or "~/.cache/{app}/log".format(app=app)).home()
                conf_dir = Path(os.environ["XDG_CONFIG_HOME"] or "~/.config/{app}".format(app=app)).home()

            else:
                root_dir = Path("/")
                run_dir = Path("/run/{app}".format(app=app))
                state_dir = Path("/var/lib/{app}".format(app=app))
                logs_dir = Path("/var/log/{app}".format(app=app))
                conf_dir = Path("/etc/{app}".format(app=app))

        return {
            "root_dir": root_dir,
            "run_dir": run_dir,
            "state_dir": state_dir,
            "logs_dir": logs_dir,
            "conf_dir": conf_dir,
        }


class CustomArguments(Arguments):
    """Argument parser from the command line."""

    def arguments(self, parser: ArgumentParser):
        """Custom program arguments."""
        parser.add_argument(
            "-l", "--listen", choices=Const.OPT_LISTEN, dest="listen", default=None,
            help="listen to a network interface. (localhost)")
        parser.add_argument(
            "-p", "--port", dest="port", default=None, type=int,
            help="listen to a network port. (22)")
        parser.add_argument(
            "config", nargs="?", default=False, type=bool,
            help="Print configuration")
        parser.add_argument(
            "-d", "--daemon", choices=["start", "stop", "restart"], dest="daemon", default=None,
            help="Run server as background process.")
        parser.add_argument(
            "--root-dir", dest="root_dir", default=None, type=PurePath,
            help="Server root directory. (/opt/angelos)")
        parser.add_argument(
            "--run-dir", dest="run_dir", default=None, type=PurePath,
            help="Runtime directory. (/run/angelos)")
        parser.add_argument(
            "--state-dir", dest="state_dir", default=None, type=PurePath,
            help="Server state directory. (/var/lib/angelos)")
        parser.add_argument(
            "--logs-dir", dest="logs_dir", default=None, type=PurePath,
            help="Logs directory. (/var/log/angelos)")
        parser.add_argument(
            "--conf-dir", dest="conf_dir", default=None,
            help="Configuration directory. (/etc/angelos)")


class Network(Extension):
    """Start a client or server.

    Only call from within async start.

    If you want to start a client, the "client" argument must be set with a client connection class.
    If you need to use a signer facade the "helper" argument must be a special facade for boot or admin support.
    """

    async def prepare(self, *args):
        server_cls = self._args.get("server", None)
        manager_cls = self._args.get("manager", None)
        helper_cls = self._args.get("helper", None)

        if helper_cls:
            facade = helper_cls.setup(Signer(self._app.args.seed))
        else:
            facade = self._app.facade

        server = await server_cls.listen(
            facade, self._app.args.listen, self._app.args.port, manager_cls(self._app),
            emergency=getattr(self._app, "emergency", None))
        self._app |= server
        return server


class Keys(Extension):
    """Key loader from hard drive."""

    def _system_key(self) -> bytes:
        KeyLoader.SYSTEM = self._args.system
        secret = KeyLoader.new()
        try:
            secret = KeyLoader.get()
        except KeyLoadError:
            KeyLoader.set(secret)
        return secret

    def prepare(self, *args):
        pass


class AngelosServer(Application):
    """Angelos server entry point"""

    CONFIG = {
        "log": Logger(name="angelos"),
        "args": CustomArguments(name="Angelos™ Server"),
        "env": BootConfigurator(default={
            "public": None,
            "admins": list(),  # Administrator public keys
            "prompt": "Angelos 0.1dX > ",
            "terminal": "Ἄγγελος safe messaging server",
            "listen": "localhost",
            "port": 443,
            "root_dir": None,
            "run_dir": None,
            "state_dir": None,
            "logs_dir": None,
            "conf_dir": None,
            "hostname": None,
            "domain": None,
            "ip": None,
            "user": None,
            "cpus": None,
            "platform": None,
            "id": None,
            "node": None,
            "release": None,
            "version": None,
            "machine": None,
            "processor": None,
        }),
        "keys": Keys(system="Ἄγγελος"),
        "sys": System(),
        "dirs": Runtime(name="angelos", desktop=False),
        "quit": Quit(),
        "signal": Signal(quit=True),
        "server": Network(server=ServerProtocolFile, manager=Connections, helper=ServerFacade)
    }

    def _initialize(self):
        self.log
        logging.debug(Util.headline("Start"))
        self.args
        self.quit
        self.env
        # self.signal
        if self.args.config:
            print(Util.headline("Environment (BEGIN)"))
            print("\n".join(Misc.recurse_env(self.env._asdict())))
            print(Util.headline("Environment (END)"))
            exit(1)

    def _finalize(self):
        self.quit.set()  # Quit is set if external keyboard interruption is triggered.
        logging.debug(Util.headline("Finish"))

    async def start(self):
        server = await self.server  # Listen happens automagically.
        task = asyncio.create_task(server.server_forever())

    async def stop(self):
        await self.quit.wait()
        self.server.close()
        self._stop()

    async def emergency(self, severity: object, protocol: Protocol):
        """Emergency button for network issues."""
        if isinstance(severity, Packet):
            logging.error("Emergency abort of connection because of panic!")
        elif isinstance(severity, ConnectionError):
            logging.error("Panic, connection refused: {}".format(severity), exc_info=severity)

        self.quit.set()
