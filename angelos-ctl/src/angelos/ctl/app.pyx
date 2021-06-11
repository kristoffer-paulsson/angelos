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
import functools
import ipaddress
import logging
import os
import re
import signal
import sys
import termios
import tty
from argparse import ArgumentParser, Namespace

from angelos.base.app import Application, Extension
from angelos.bin.nacl import Signer
from angelos.common.utils import Util
from angelos.ctl.support import AdminFacade
from angelos.net.authentication import AuthenticationHandler
from angelos.net.broker import ServiceBrokerClient
from angelos.net.net import Client
from angelos.net.tty import TTYClient, TTYHandler

facade = None
server = None


class TestClient(Client):
    """Stub protocol client."""

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        Client.connection_made(self, transport)
        self._add_handler(TTYClient(self))


class Application_:
    """Application for terminal emulator."""

    server = None
    manager = None
    task = None

    def __init__(self):
        self._args = None
        self._signer = None
        self._quiter = None
        self._facade = None
        self._client = None

        self._tty = None
        self._echo = None
        self._no_echo = None

        self._terminal = None

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
        self._quit()

    def _sigwinch_handler(self):
        size = os.get_terminal_size()
        if self._terminal:
            self._terminal.resize(max(80, min(240, size.columns)), max(8, min(72, size.lines)))

    def _input_handler(self):
        data = sys.stdin.buffer.read1()

        if self._terminal:
            self._terminal.send(data)

        if b'\x03' in data:
            self._quit()

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
        # Don't use, destroys typing handling.
        # termios.tcsetattr(self._tty, termios.TCSADRAIN, self._no_echo)

    def _teardown_term(self):
        termios.tcsetattr(self._tty, termios.TCSADRAIN, self._echo)

    async def _setup_conn(self):
        self._client = await TestClient.connect(self._facade, self._args.host[0], self._args.port)
        await self._client.get_handler(AuthenticationHandler.RANGE).auth_admin()
        await asyncio.sleep(.1)
        terminal_available = await self._client.get_handler(ServiceBrokerClient.RANGE).request(TTYHandler.RANGE)

        if not terminal_available:
            print("Terminal not available at host, exiting.")
            self._quit()
        else:
            size = os.get_terminal_size()
            self._terminal = await self._client.get_handler(TTYHandler.RANGE).pty(
                max(80, min(240, size.columns)), max(8, min(72, size.lines))
            )

    def _teardown_conn(self):
        self._client.close()

    async def _initialize(self):
        self._quiter = asyncio.Event()
        self._quiter.clear()

        await asyncio.wait_for(self._setup_conn(), timeout=10)
        self._setup_term()

    async def _finalize(self):
        self._teardown_term()
        self._teardown_conn()

    async def run(self):
        """Application main loop."""
        await self._initialize()
        await self._quiter.wait()
        await self._finalize()

    def start(self):
        """Start application main loop."""
        try:
            logging.basicConfig(
                filename="angelosctl.log",
                level=logging.DEBUG,
                format="%(relativeCreated)6d %(threadName)s %(message)s"
            )
            self._args = self._arguments()
            self._facade = self._setup_facade()

            asyncio.run(self.run())
        except KeyboardInterrupt:
            print("Uncaught keyboard interrupt")
        except Exception as exc:
            Util.print_exception(exc)


class Arguments(Extension):
    """Argument parser from the command line."""

    def __call__(self, *args):
        parser = ArgumentParser(self._args.get("name", "Unkown program"))
        parser.add_argument("host", nargs=1, type=ipaddress.ip_address, help="IP address of server")
        parser.add_argument("-p", "--port", dest="port", default=443, type=int, help="Server port")
        parser.add_argument(
            "-s", "--seed", dest="seed", required=True,
            type=lambda x: (re.match(r"^[0-9a-fA-F]{64}$", x), binascii.unhexlify(x))[1],
            help="Encryption key"
        )

        return parser.parse_args()


class Quit(Extension):
    """Prepares a general quit/exit flag with an event."""

    def __call__(self, *args):
        event = asyncio.Event()
        event.clear()
        return event


class Signal(Extension):
    """Configure witch signals to be caught and how to handle them. Override to get custom handling."""

    EXIT = signal.CTRL_C_EVENT if os.name == "nt" else signal.SIGINT
    TERM = signal.SIGWINCH

    def __call__(self, *args):
        loop = asyncio.get_event_loop()

        if self._args.get("quit", False):
            loop.add_signal_handler(self.EXIT, functools.partial(self.quit, args[0]))

        if self._args.get("term", False):
            loop.add_signal_handler(self.TERM, functools.partial(self.size_chage, args[0]))

    def quit(self, app: Application):
        """Trigger the quit flag if Quit extension is used."""
        try:
            app.quit.set()
        except NameError:
            pass
        else:
            asyncio.get_event_loop().remove_signal_handler(self.EXIT)

    def size_change(self, app: Application):
        return NotImplemented


class AngelosAdmin(Application):
    """Angelos admin control client software program."""

    CONFIG = {
        "args": Arguments(name="Angelos Admin Utility"),
        "quit": Quit(),
        "signal": Signal(quit=True, term=True),
    }

    def _initialize(self):
        print(self.args.seed)

    def _finalize(self):
        self.quit.set()  # Quit is set if external keyboard interruption is triggered.

    async def stop(self):
        await self.quit.wait()