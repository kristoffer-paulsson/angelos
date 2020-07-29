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
import collections
import functools
import json
import os
import signal
import socket
from typing import Any

import asyncssh
from angelos.common.misc import Misc
from angelos.common.utils import Event, Util

from angelos.lib.automatic import Automatic, Platform, Runtime, Server as ServerDirs, Network
from angelos.lib.facade.facade import Facade
from angelos.lib.ioc import Container, Config, Handle, StaticHandle, LogAware
from angelos.lib.ssh.ssh import SessionManager
from angelos.lib.starter import Starter
from angelos.lib.worker import Worker
from angelos.server.logger import Logger
from angelos.server.parser import Parser
from angelos.server.starter import ConsoleStarter
from angelos.server.state import StateMachine
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
        self.__key_list = asyncssh.read_public_key_list(self.__path_admin)

        if not os.path.isfile(self.__path_server):
            print("Private key missing, generate new.")
            self.__key_private = asyncssh.generate_private_key("ssh-rsa")
            self.__key_private.write_private_key(self.__path_server)
        else:
            self.__key_private = asyncssh.read_private_key(self.__path_server)

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
            self.__error("Permission denied to use port {}".format(self.__env["port"]))
            return

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
                vars(self.auto),
                self.__load("env.json"),
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
            "boot": lambda self: StaticHandle(asyncio.base_events.Server),
            "admin": lambda self: StaticHandle(asyncio.base_events.Server),
            "clients": lambda self: Handle(asyncio.base_events.Server),
            "nodes": lambda self: Handle(asyncio.base_events.Server),
            "hosts": lambda self: Handle(asyncio.base_events.Server),
            "opts": lambda self: Parser(),
            "auto": lambda self: Auto("Angelos", self.opts),
            "quit": lambda self: Event(),
        }


class Server(LogAware):
    """Main server application class."""

    def __init__(self):
        """Initialize app logger."""
        LogAware.__init__(self, Configuration())
        self._worker = Worker("server.main", self.ioc, executor=0, new=False)

    def _initialize(self):
        loop = self._worker.loop

        loop.add_signal_handler(
            signal.SIGINT, functools.partial(self.quiter, signal.SIGINT)
        )

        loop.add_signal_handler(
            signal.SIGTERM, functools.partial(self.quiter, signal.SIGTERM)
        )

        self._worker.run_coroutine(self.bootstrap())
        self._worker.run_coroutine(self.boot_server())
        self._worker.run_coroutine(self.admin_server())
        self._worker.run_coroutine(self.clients_server())
        self._worker.run_coroutine(self.hosts_server())
        self._worker.run_coroutine(self.nodes_server())
        self._worker.run_coroutine(self.boot_activator())

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
            raise KeyboardInterrupt()
        else:
            self.ioc.state("running", True)

    async def admin_server(self):
        try:
            first = True
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("serving"):
                    await self.ioc.state.off("serving")
                    server = self.ioc.admin
                    server.close()
                    await self.ioc.session.unreg_server("admin")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("serving")
                    if first:
                        self.ioc.admin = await ConsoleStarter().admin_server(
                            self._listen(),
                            port=self.ioc.env["port"],
                            ioc=self.ioc,
                            loop=self._worker.loop,
                        )
                        self.ioc.session.reg_server("admin", self.ioc.admin)
                        first = False
                    else:
                        await self.ioc.admin.start_serving()
        except Exception as exc:
            Util.print_exception(exc)

    async def boot_server(self):
        try:
            first = True
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("boot"):
                    await self.ioc.state.off("boot")
                    self.normal("Boot server turned OFF")
                    server = self.ioc.boot
                    server.close()
                    await self.ioc.session.unreg_server("boot")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("boot")
                    self.normal("Boot server turned ON")
                    if first:
                        self.ioc.boot = await ConsoleStarter().boot_server(
                            self._listen(),
                            port=self.ioc.env["port"],
                            ioc=self.ioc,
                            loop=self._worker.loop,
                        )
                        self.ioc.session.reg_server("boot", self.ioc.boot)
                        first = False
                    else:
                        await self.ioc.boot.start_serving()
        except Exception as exc:
            Util.print_exception(exc)

    async def clients_server(self):
        try:
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("clients"):
                    await self.ioc.state.off("clients")
                    self.normal("Clients server turned OFF")
                    server = self.ioc.clients
                    server.close()
                    await self.ioc.session.unreg_server("clients")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("clients")
                    self.normal("Clients server turned ON")
                    self.ioc.clients = await Starter().clients_server(
                        self.ioc.facade.data.portfolio,
                        self._listen(),
                        port=self.ioc.config["ports"]["clients"],
                        ioc=self.ioc,
                        loop=self._worker.loop,
                    )
                    self.ioc.session.reg_server("clients", self.ioc.clients)
        except Exception as exc:
            Util.print_exception(exc)

    async def hosts_server(self):
        try:
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("hosts"):
                    await self.ioc.state.off("hosts")
                    self.normal("Hosts server turned OFF")
                    server = self.ioc.hosts
                    server.close()
                    await self.ioc.session.unreg_server("hosts")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("hosts")
                    self.normal("Hosts server turned ON")
                    self.ioc.hosts = await ConsoleStarter().hosts_server(
                        self.ioc.facade.data.portfolio,
                        self._listen(),
                        port=self.ioc.config["ports"]["hosts"],
                        ioc=self.ioc,
                        loop=self._worker.loop,
                    )
                    self.ioc.session.reg_server("hosts", self.ioc.hosts)
        except Exception as exc:
            Util.print_exception(exc)

    async def nodes_server(self):
        try:
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("nodes"):
                    self.normal("Nodes server turned OFF")
                    await self.ioc.state.off("nodes")
                    server = self.ioc.nodes
                    server.close()
                    await self.ioc.session.unreg_server("nodes")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("nodes")
                    self.normal("Nodes server turned ON")
                    self.ioc.nodes = await Starter().nodes_server(
                        self.ioc.facade.data.portfolio,
                        self._listen(),
                        port=self.ioc.config["ports"]["nodes"],
                        ioc=self.ioc,
                        loop=self._worker.loop,
                    )
                    self.ioc.session.reg_server("nodes", self.ioc.nodes)
        except Exception as exc:
            Util.print_exception(exc)

    async def boot_activator(self):
        await asyncio.sleep(1)
        self.ioc.state("boot", True)
