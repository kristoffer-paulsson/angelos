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
import collections
import errno
import functools
import json
import os
import signal
import socket
from typing import Any

from angelos.bin.nacl import Signer
from angelos.common.misc import Misc
from angelos.common.utils import Event, Util
from angelos.facade.facade import Facade
from angelos.lib.automatic import Automatic, Platform, Runtime, Server as ServerDirs, Network
from angelos.lib.ioc import Container, Config, StaticHandle, LogAware
from angelos.lib.ssh.ssh import SessionManager
from angelos.server.logger import Logger
from angelos.server.network import ServerProtocolFile, Connections
from angelos.server.parser import Parser
from angelos.server.state import StateMachine
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

    def __init__(self, env: collections.ChainMap):
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
            self.__key_list = [x.strip() for x in f.readlines()]

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
    def __init__(self, env: collections.ChainMap, keys: AdminKeys):
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
            "env": lambda self: collections.ChainMap(
                ENV_IMMUTABLE,
                {key: value for key, value in vars(self.opts).items() if value},
                self.__load("env.json"),
                vars(self.auto),
                ENV_DEFAULT,
            ),
            "config": lambda self: collections.ChainMap(
                CONFIG_IMMUTABLE,
                self.__load("config.json"),
                CONFIG_DEFAULT
            ),
            "bootstrap": lambda self: Bootstrap(self.env, self.keys),
            "keys": lambda self: AdminKeys(self.env),
            "state": lambda self: StateMachine(self.config["state"]),
            "log": lambda self: Logger(self.facade.secret, self.env["logs_dir"]),
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

    async def start(self):
        """Start serving."""
        self._connections = Connections()
        self._server = await ServerProtocolFile.listen(
            ServerFacade.setup(Signer(self.ioc.keys.server())),
            self._listen(), self.ioc.env["port"], self._connections
        )
        self._server_task = asyncio.create_task(self._server.serve_forever())

    async def stop(self):
        """Wait for quit to stop serving."""
        await self.ioc.quit.wait()
        self._server.close()
        await self._server.wait_closed()

    def _initialize(self):
        loop = asyncio.get_event_loop()
        loop.add_signal_handler(
            signal.SIGINT, functools.partial(self.quiter, signal.SIGINT)
        )
        loop.add_signal_handler(
            signal.SIGTERM, functools.partial(self.quiter, signal.SIGTERM)
        )

        loop.create_task(self.start())
        loop.create_task(self.stop())

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

    async def bootstrap(self):
        """Bootstraps the Angelos server by performing checks before changing state into running."""
        if not self.ioc.bootstrap.match():
            self._return_code = 2
            raise KeyboardInterrupt()
        else:
            self.ioc.state("running", True)
