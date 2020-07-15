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
import logging
import os
import signal
import socket
from typing import Any

import asyncssh
from angelos.parser import Parser
from angelos.state import StateMachine
from angelos.vars import ENV_DEFAULT, ENV_IMMUTABLE, CONFIG_DEFAULT, CONFIG_IMMUTABLE
from libangelos.automatic import Automatic
from libangelos.ioc import Container, ContainerAware, Config, Handle, StaticHandle
from libangelos.ssh.ssh import SessionManager
from libangelos.utils import Event
from libangelos.worker import Worker

from angelos.starter import ConsoleStarter
from libangelos.facade.facade import Facade
from libangelos.logger import LogHandler
from libangelos.starter import Starter


class AdminKeys:
    """Load and list admin keys."""

    def __init__(self, env: collections.ChainMap):
        self.__path_admin = os.path.join(env["dir"].root, "admins.pub")
        self.__path_server = os.path.join(env["dir"].root, "server")
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
            logging.info("Private key missing, generate new.")
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
        logging.error(message)
        print(message)
        self.__critical = True

    def criteria_root(self):
        """Check that the root folder exists."""
        root_dir = self.__env["dir"].root

        if not os.path.isdir(root_dir):
            self.__error("No root directory. ({})".format(root_dir))
            return

        if not os.access(root_dir, os.W_OK):
            self.__error("Root directory not writable. ({})".format(root_dir))
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
            s.bind(("127.0.0.1", self.__env["opts"].port))
            s.listen(1)
            s.close()
        except PermissionError:
            self.__error("Permission denied to use port {}".format(self.__env["opts"].port))
            return

    def match(self) -> bool:
        """Match all criteria for proceeding operations."""

        self.criteria_root()
        self.criteria_admin()
        self.criteria_load_keys()
        self.criteria_port_access()

        if self.__critical:
            logging.critical("One or several bootstrap criteria failed!")
            print("Exit")
            return False
        else:
            logging.info("Bootstrap criteria success.")
            return True


class Configuration(Config, Container):
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
            "bootstrap": lambda self: Bootstrap(self.env, self.keys),
            "keys": lambda self: AdminKeys(self.env),
            "state": lambda self: StateMachine(self.config["state"]),
            "log": lambda self: LogHandler(self.config["logger"]),
            "session": lambda self: SessionManager(),
            "facade": lambda self: StaticHandle(Facade),
            "boot": lambda self: StaticHandle(asyncio.base_events.Server),
            "admin": lambda self: StaticHandle(asyncio.base_events.Server),
            "clients": lambda self: Handle(asyncio.base_events.Server),
            "nodes": lambda self: Handle(asyncio.base_events.Server),
            "hosts": lambda self: Handle(asyncio.base_events.Server),
            "opts": lambda self: Parser(),
            "auto": lambda self: Automatic("angelos", self.opts),
            "quit": lambda self: Event(),
        }


class Server(ContainerAware):
    """Main server application class."""

    def __init__(self):
        """Initialize app logger."""
        ContainerAware.__init__(self, Configuration())
        self._worker = Worker("server.main", self.ioc, executor=0, new=False)
        self._applog = self.ioc.log.app

    def _initialize(self):
        # self.ioc.state("running", True)
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

        self._applog.info("Starting boot server.")

    def _finalize(self):
        self._applog.info("Shutting down server.")
        self._applog.info("Server quitting.")

    def _listen(self):
        la = self.ioc.env["opts"].listen
        if la == "localhost":
            listen = "localhost"
        elif la == "loopback":
            listen = "127.0.0.1"
        elif la == "hostname":
            listen = self.ioc.env["net"].hostname
        elif la == "domain":
            listen = self.ioc.env["net"].domain
        elif la == "ip":
            listen = self.ioc.env["net"].ip
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
        self._applog.info("-------- STARTING SERVER --------")

        self._initialize()
        try:
            asyncio.get_event_loop().run_forever()
        except KeyboardInterrupt:
            pass
        except Exception as e:
            self._applog.critical(
                "Server crashed due to unhandled exception: %s" % e
            )
            self._applog.exception(e)
        self._finalize()

        self._applog.info("-------- EXITING SERVER --------")

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
                            port=self.ioc.env["opts"].port,
                            ioc=self.ioc,
                            loop=self._worker.loop,
                        )
                        self.ioc.session.reg_server("admin", self.ioc.admin)
                        first = False
                    else:
                        await self.ioc.admin.start_serving()
        except Exception as e:
            self._applog.critical("Admin server encountered a critical error.")
            self._applog.exception(e, exc_info=True)

    async def boot_server(self):
        try:
            first = True
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("boot"):
                    await self.ioc.state.off("boot")
                    self._applog.info("Boot server turned OFF")
                    server = self.ioc.boot
                    server.close()
                    await self.ioc.session.unreg_server("boot")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("boot")
                    self._applog.info("Boot server turned ON")
                    if first:
                        self.ioc.boot = await ConsoleStarter().boot_server(
                            self._listen(),
                            port=self.ioc.env["opts"].port,
                            ioc=self.ioc,
                            loop=self._worker.loop,
                        )
                        self.ioc.session.reg_server("boot", self.ioc.boot)
                        first = False
                    else:
                        await self.ioc.boot.start_serving()
        except Exception as e:
            self._applog.critical("Boot server encountered a critical error.")
            self._applog.exception(e, exc_info=True)

    async def clients_server(self):
        try:
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("clients"):
                    await self.ioc.state.off("clients")
                    self._applog.info("Clients server turned OFF")
                    server = self.ioc.clients
                    server.close()
                    await self.ioc.session.unreg_server("clients")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("clients")
                    self._applog.info("Clients server turned ON")
                    self.ioc.clients = await Starter().clients_server(
                        self.ioc.facade.data.portfolio,
                        self._listen(),
                        port=self.ioc.config["ports"]["clients"],
                        ioc=self.ioc,
                        loop=self._worker.loop,
                    )
                    self.ioc.session.reg_server("clients", self.ioc.clients)
        except Exception as e:
            self._applog.critical(
                "Clients server encountered a critical error."
            )
            self._applog.exception(e, exc_info=True)

    async def hosts_server(self):
        try:
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("hosts"):
                    await self.ioc.state.off("hosts")
                    self._applog.info("Hosts server turned OFF")
                    server = self.ioc.hosts
                    server.close()
                    await self.ioc.session.unreg_server("hosts")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("hosts")
                    self._applog.info("Hosts server turned ON")
                    self.ioc.hosts = await ConsoleStarter().hosts_server(
                        self.ioc.facade.data.portfolio,
                        self._listen(),
                        port=self.ioc.config["ports"]["hosts"],
                        ioc=self.ioc,
                        loop=self._worker.loop,
                    )
                    self.ioc.session.reg_server("hosts", self.ioc.hosts)
        except Exception as e:
            self._applog.critical("Hosts server encountered a critical error.")
            self._applog.exception(e, exc_info=True)

    async def nodes_server(self):
        try:
            while not self.ioc.quit.is_set():
                if self.ioc.state.position("nodes"):
                    self._applog.info("Nodes server turned OFF")
                    await self.ioc.state.off("nodes")
                    server = self.ioc.nodes
                    server.close()
                    await self.ioc.session.unreg_server("nodes")
                    await server.wait_closed()
                else:
                    await self.ioc.state.on("nodes")
                    self._applog.info("Nodes server turned ON")
                    self.ioc.nodes = await Starter().nodes_server(
                        self.ioc.facade.data.portfolio,
                        self._listen(),
                        port=self.ioc.config["ports"]["nodes"],
                        ioc=self.ioc,
                        loop=self._worker.loop,
                    )
                    self.ioc.session.reg_server("nodes", self.ioc.nodes)
        except Exception as e:
            self._applog.critical("Nodes server encountered a critical error.")
            self._applog.exception(e, exc_info=True)

    async def boot_activator(self):
        await asyncio.sleep(1)
        self.ioc.state("boot", True)
