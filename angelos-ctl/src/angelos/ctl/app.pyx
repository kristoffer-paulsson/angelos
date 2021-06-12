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
from io import BufferedRWPair, DEFAULT_BUFFER_SIZE

from angelos.base.app import Application, Extension, OptimizedLogRecord
from angelos.bin.nacl import Signer
from angelos.common.utils import Util
from angelos.ctl.network import ClientAdmin, AuthenticationFailure, ServiceNotAvailable
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


class Logger(Extension):
    """Sets up a logger."""

    def __call__(self, *args):
        ioc = args[0]
        logging.setLogRecordFactory(OptimizedLogRecord)
        logger = logging.getLogger()
        logger.setLevel(logging.DEBUG)

        file = logging.FileHandler(self._args.get("name", "unknown") + ".log")
        file.addFilter(self._filter_file)
        logger.addHandler(file)

        stream = logging.StreamHandler(sys.stderr)
        stream.addFilter(self._filter_stream)
        logger.addHandler(stream)

        return logger

    def _filter_file(self, rec: logging.LogRecord):
        return rec.levelname != "INFO"

    def _filter_stream(self, rec: logging.LogRecord):
        return rec.levelname == "INFO"


class Arguments(Extension):
    """Argument parser from the command line."""

    def prepare(self, *args):
        parser = ArgumentParser(self._args.get("name", "Unknown program"))
        parser.add_argument("host", type=ipaddress.ip_address, help="IP address of server")
        parser.add_argument("-p", "--port", dest="port", default=443, type=int, help="Server port")
        parser.add_argument(
            "-s", "--seed", dest="seed", required=True,
            type=lambda x: (re.match(r"^[0-9a-fA-F]{64}$", x), binascii.unhexlify(x))[1],
            help="Encryption key"
        )

        return parser.parse_args()


class Quit(Extension):
    """Prepares a general quit/exit flag with an event."""

    EVENT = asyncio.Event()

    def __init__(self):
        super().__init__()
        self.EVENT.clear()

    def prepare(self, *args):
        return self.EVENT


class Signal(Extension):
    """Configure witch signals to be caught and how to handle them. Override to get custom handling."""

    EXIT = signal.CTRL_C_EVENT if os.name == "nt" else signal.SIGINT
    TERM = signal.SIGWINCH

    def prepare(self, *args):
        loop = self.get_loop()

        if self._args.get("quit", False):
            loop.add_signal_handler(self.EXIT, functools.partial(self.quit))

        if self._args.get("term", False):
            loop.add_signal_handler(self.TERM, functools.partial(self.size_change))

    def quit(self):
        """Trigger the quit flag if Quit extension is used."""
        q = self.get_quit()
        if q:
            q.set()
        self.get_loop().remove_signal_handler(self.EXIT)

    def size_change(self):
        return NotImplemented


class Network(Extension):
    """Start a client or server.

    Only call from within async start.

    If you want to start a client, the "client" argument must be set with a client connection class.
    If you need to use a signer facade the "helper" argument must be a special facade for boot or admin support.
    """

    async def prepare(self, *args):
        loop = self.get_loop()

        client_cls = self._args.get("client", None)
        helper_cls = self._args.get("helper", None)

        if helper_cls:
            facade = helper_cls.setup(Signer(self._app.args.seed))
        else:
            facade = self._app.facade

        return await client_cls.connect(facade, self._app.args.host, self._app.args.port)


class Pipes(Extension):
    """Pipe pairs to calling and called process."""

    def prepare(self, *args):
        loop = self.get_loop()

        reader = self._args.get("reader", None)
        writer = self._args.get("writer", None)

        pair = BufferedRWPair(
            reader=reader,
            writer=writer,
            buffer_size=self._args.get("size", DEFAULT_BUFFER_SIZE))

        if self._args.get("inp_auto", False) and hasattr(self._app, "input_handler"):
            loop.add_reader(reader, self._app.input_handler, pair)
        if self._args.get("outp_auto", False) and hasattr(self._app, "output_handler"):
            loop.add(writer, self._app.output_handler, pair)

        return pair


class AngelosAdmin(Application):
    """Angelos admin control client software program."""

    CONFIG = {
        "log": Logger(name="angelosctl"),
        "args": Arguments(name="Angelos Admin Utility"),
        "quit": Quit(),
        "signal": Signal(quit=True, term=True),
        "client": Network(client=ClientAdmin, helper=AdminFacade)
    }

    def _initialize(self):
        self.log
        self.args
        logging.debug(Util.headline("Start"))
        self.quit
        # self.signal

    def _finalize(self):
        self.quit.set()  # Quit is set if external keyboard interruption is triggered.
        logging.debug(Util.headline("Finish"))

    async def start(self):
        try:
            client = await self.client  # Connect happens automagically.
            await client.authenticate()
            await asyncio.sleep(.1)
            terminal = await client.open()
        except (ConnectionRefusedError, AuthenticationFailure, ServiceNotAvailable) as exc:
            logging.error("Connection refused: {}".format(exc))
            logging.info("Connection refused to {}:{}".format(self.args.host, self.args.port))
            self.quit.set()

    async def stop(self):
        await self.quit.wait()
        self.client.close()
        self._stop()