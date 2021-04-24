# cython: language_level=3
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Application class for the terminal control program."""
import asyncio
import binascii
import copy
import ipaddress
import os
import re
import signal
import sys
import termios
import tty
from argparse import ArgumentParser, Namespace

from angelos.bin.nacl import Signer
from angelos.common.utils import Util
from angelos.ctl.support import AdminFacade
from angelos.meta.testing.net import FacadeContext
from angelos.net.authentication import AdminAuthMixin, AuthenticationHandler
from angelos.net.base import ConnectionManager
from angelos.net.broker import ServiceBrokerClient
from angelos.net.net import Server, Client
from angelos.net.tty import TTYServer, TTYClient, TTYHandler

facade = None
server = None


class TestClient(Client):
    """Stub protocol client."""

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        Client.connection_made(self, transport)
        self._add_handler(TTYClient(self))


class TestServer(Server, AdminAuthMixin):
    """Stub protocol server."""

    admin = b""

    def pub_key_find(self, key: bytes) -> bool:
        return key == self.admin

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        Server.connection_made(self, transport)
        self._add_handler(TTYServer(self))


class Application:
    """Application for terminal emulator."""

    server = None
    manager = None
    task = None

    def __init__(self):
        self._args = None
        self._signer = None
        self._quiter = None
        self._task = None
        self._facade = None
        self._client = None

        self._tty = None
        self._echo = None
        self._no_echo = None

    def _arguments(self) -> Namespace:
        """Build argument parser."""
        parser = ArgumentParser("Angelos Admin Utility")
        parser.add_argument("host", nargs=1, type=ipaddress.ip_address, help="IP address of server")
        parser.add_argument("-p", "--port", dest="port", default=443, type=int, help="Server port")
        parser.add_argument(
            "-s", "--seed", dest="seed", required=True,
            type=lambda x: (re.match(r"^[0-9a-fA-F]{64}$", x), binascii.unhexlify(x))[1],
            help="Encryption key"
        )

        return parser.parse_args()

    def _setup_facade(self):
        self._signer = Signer(self._args.seed)
        return AdminFacade.setup(self._signer)

    def _quit(self):
        self._quiter.set()

    def _sigint_handler(self):
        self.on_quit()
        self._quit()

    def _sigwinch_handler(self):
        size = os.get_terminal_size()
        self.on_resize(size.columns, size.lines)

    def _input_handler(self):
        self.on_input(sys.stdin.buffer.read1())

    def on_quit(self):
        """Override this method to act upon program quit."""
        pass

    def on_resize(self, columns: int, lines: int):
        """Override this method to act upon terminal resize."""
        print(columns, lines)

    def on_input(self, text: bytes):
        """Override this method to act upon user keypress."""
        print("Seq:", text)

    def _setup_term(self):
        self._tty = sys.stdin.fileno()
        self._echo = termios.tcgetattr(self._tty)
        self._no_echo = copy.copy(self._echo)
        self._no_echo[3] = self._no_echo[3] & ~termios.ECHO

        tty.setraw(self._tty)
        asyncio.get_event_loop().add_signal_handler(
            signal.CTRL_C_EVENT if os.name == "nt" else signal.SIGINT, self._sigint_handler)
        asyncio.get_event_loop().add_signal_handler(signal.SIGWINCH, self._sigwinch_handler)

        asyncio.get_event_loop().add_reader(sys.stdin, self._input_handler)
        # termios.tcsetattr(self._tty, termios.TCSADRAIN, self._no_echo)

    def _teardown_term(self):
        termios.tcsetattr(self._tty, termios.TCSADRAIN, self._echo)

    async def _setup_conn(self):
        TestServer.admin = self._signer.vk

        self.manager = ConnectionManager()
        self.server = FacadeContext.create_server()
        self._server = await TestServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        self.task = asyncio.create_task(self._server.serve_forever())
        await asyncio.sleep(0)

        self._client = await TestClient.connect(self._facade, "127.0.0.1", 8080)
        await self._client.get_handler(AuthenticationHandler.RANGE).auth_admin()
        await asyncio.sleep(.1)
        terminal_available = await self._client.get_handler(ServiceBrokerClient.RANGE).request(TTYHandler.RANGE)

        if not terminal_available:
            self._quit()
        else:
            terminal = await self._client.get_handler(TTYHandler.RANGE).pty()

    def _teardown_conn(self):
        self._client.close()

    async def _initialize(self):
        self._quiter = asyncio.Event()
        self._quiter.clear()

        await self._setup_conn()
        # self._setup_term()

    async def _finalize(self):
        # self._teardown_term()
        self._teardown_conn()

    async def run(self):
        """Application main loop."""
        await self._initialize()
        await self._quiter.wait()
        await self._finalize()

    def start(self):
        """Start application main loop."""
        try:
            self._args = self._arguments()
            self._facade = self._setup_facade()

            asyncio.run(self.run())
        except KeyboardInterrupt:
            print("Uncaught keyboard interrupt")
        except Exception as exc:
            Util.print_exception(exc)
