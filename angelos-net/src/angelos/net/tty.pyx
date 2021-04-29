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
"""TTY terminal emulator and shell with commands as protocol handler."""

# Pyte VT100 terminal https://github.com/selectel/pyte
# $ click_ Command Line Interface Creation Kit https://github.com/pallets/click/
# cmd2 https://github.com/python-cmd2/cmd2
# https://github.com/ronf/asyncssh/blob/875330da4bb0322d872f702dbb1f44c7e6137c48/asyncssh/editor.py#L273
# https://espterm.github.io/docs/VT100%20escape%20codes.html
import asyncio
import hashlib
import re
import sys
import typing
from struct import Struct

import msgpack
from angelos.common.misc import SyncCallable, AsyncCallable
from angelos.net.base import Handler, StateMode, Protocol, PullChunkIterator, PushChunkIterator, ChunkError, \
    NetworkState, ConfirmCode, ProtocolNegotiationError, NetworkSession, NetworkIterator
from angelos.net.pyte import HistoryScreen, LNM, ByteStream
from angelos.net.shell import Shell

"""# Change terminal window size from python.
import sys
sys.stdout.write("\x1b[8;{rows};{cols}t".format(rows=32, cols=100))
"""

"""# Signal handlers.
def init_signals(self) -> None:
        # Set up signals through the event loop API.

        self.loop.add_signal_handler(signal.SIGQUIT, self.handle_quit,
                                     signal.SIGQUIT, None)

        self.loop.add_signal_handler(signal.SIGTERM, self.handle_exit,
                                     signal.SIGTERM, None)

        self.loop.add_signal_handler(signal.SIGINT, self.handle_quit,
                                     signal.SIGINT, None)

        self.loop.add_signal_handler(signal.SIGWINCH, self.handle_winch,
                                     signal.SIGWINCH, None)

        self.loop.add_signal_handler(signal.SIGUSR1, self.handle_usr1,
                                     signal.SIGUSR1, None)

        self.loop.add_signal_handler(signal.SIGABRT, self.handle_abort,
                                     signal.SIGABRT, None)

        # Don't let SIGTERM and SIGUSR1 disturb active requests
        # by interrupting system calls
        signal.siginterrupt(signal.SIGTERM, False)
        signal.siginterrupt(signal.SIGUSR1, False)
"""

"""# Check for terminal session.
sys.stdout.isatty()
os.isatty(fd)
os.get_terminal_size(fd=)
"""


FG_ANSI = {
    "black": 30,
    "red": 31,
    "green": 31,
    "brown": 33,
    "blue": 34,
    "magenta": 35,
    "cyan": 36,
    "white": 37,
    "default": 39  # white.
}

BG_ANSI = {
    "black": 40,
    "red": 41,
    "green": 42,
    "brown": 43,
    "blue": 44,
    "magenta": 45,
    "cyan": 46,
    "white": 47,
    "default": 49  # black.
}


class TerminalClient:
    """Client side terminal emulator."""

    def __init__(self, client: "TTYClient"):
        self._client = client

    def handle(self, data: bytes):
        """Receive terminal output information."""
        info = msgpack.unpackb(data, raw=False)
        if isinstance(info, dict):
            if info["type"] == "cursor":
                print("\x1b[{cols};{lines}H".format(info["cursor"][1],info["cursor"][0]))
            if info["type"] == "row":
                line = "\x1b[{};0H{}".format(info["y"], info["row"])
                print(line.rstrip())

    def send(self, data: bytes):
        """Send text and sequences to server."""
        self._client.send(data)


TERMINAL_VERSION = b"tty-0.1"

SESH_TYPE_DOWNSTREAM = 0x01
SESH_TYPE_UPSTREAM = 0x02


class DownstreamIterator(PullChunkIterator):
    """Test stub iterator item push with states."""

    ST_SIZE = 0x02

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PullChunkIterator.__init__(self, handler, server, SESH_TYPE_DOWNSTREAM, session, {
            # self.ST_SIZE: (StateMode.FACT, b""),
        }, 0, check)
        self._queue = None

    async def pull_chunk(self) -> typing.Tuple[bytes, bytes]:
        """Pull chunk from queue on server and send it."""
        chunk = await self._queue.get()
        return chunk, hashlib.sha1(chunk).digest()

    def source(self, queue: asyncio.Queue):
        """Set server chunk queue."""
        self._queue = queue


class UpstreamIterator(PushChunkIterator):
    """Test stub iterator item push with states."""

    ST_SIZE = 0x02

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PushChunkIterator.__init__(self, handler, server, SESH_TYPE_UPSTREAM, session, {
            # self.ST_SIZE: (StateMode.ONCE, b""),
        }, 0, check)
        self._tty = None

    async def push_chunk(self, chunk: bytes, digest: bytes):
        """Handle pushed chunk from client."""
        if hashlib.sha1(chunk).digest() != digest:
            raise ChunkError()
        self._tty.handle(chunk)

    def source(self, tty: "TTYServer"):
        """Set chunk handle callable."""
        self._tty = tty


class TTYScreen(HistoryScreen):

    def __init__(self, columns: int, lines: int, shell: Shell):
        HistoryScreen.__init__(self, columns, lines, history=100, ratio=.5)
        self._shell = shell

    def write_process_input(self, data: bytes):
        self._shell.write(data)


class TTYHandler(Handler):
    LEVEL = 1
    RANGE = 4

    ST_VERSION = 0x01

    SESH_DOWNSTREAM = SESH_TYPE_DOWNSTREAM
    SESH_UPSTREAM = SESH_TYPE_UPSTREAM

    def __init__(self, manager: Protocol):
        Handler.__init__(self, manager, states={
            self.ST_VERSION: (StateMode.MEDIATE, TERMINAL_VERSION),
        },
        sessions = {
           self.SESH_DOWNSTREAM: (DownstreamIterator, dict()),
           self.SESH_UPSTREAM: (UpstreamIterator, dict()),
        }, max_sesh = 2)
        self._quit = asyncio.Event()
        self._seq = asyncio.Queue()
        self._idle = None

    async def _idler(self):
        while not self._quit.is_set():
            self._seq.put_nowait(b"\x00")
            await asyncio.sleep(.5)

    def send(self, data: bytes):
        """Send commands to PTY."""
        self._seq.put_nowait(data)

    async def _handle(self, data: bytes):
        """Handle incoming sequences."""
        pass


class TTYClient(TTYHandler):

    def __init__(self, manager: Protocol):
        TTYHandler.__init__(self, manager)
        self._up = None
        self._down = None
        self._terminal = None

    async def pty(self) -> TerminalClient:
        """Start a new PTY session."""
        await self._manager.ready()

        version = await self._call_mediate(self.ST_VERSION, [TERMINAL_VERSION])
        if version is None:
            raise ProtocolNegotiationError()

        self._terminal = TerminalClient(self)
        self._up = asyncio.create_task(self._upstream())
        self._idle = asyncio.create_task(self._idler())
        self._down = asyncio.create_task(self._downstream())

        return self._terminal

    async def _upstream(self):
        """Upload sent mail."""
        async with self._sesh_context(self.SESH_UPSTREAM) as sesh:
            data = await self._call_tell(NetworkIterator.ST_COUNT, sesh)
            count = int.from_bytes(data, "big", signed=False)
            async for chunk, digest in self._chunk_iter():
                await self._push_chunk(sesh, chunk, digest)

    async def _chunk_iter(self):
        """Iterate over a queue of chunks."""
        while not self._quit.is_set():
            chunk = await self._seq.get()
            yield chunk, hashlib.sha1(chunk).digest()

    async def _downstream(self):
        """Download received mail."""
        async with self._sesh_context(self.SESH_DOWNSTREAM) as sesh:
            await self._call_query(NetworkIterator.ST_COUNT, sesh)
            try:
                async for chunk, digest in self._iter_pull_chunk(sesh):
                    if hashlib.sha1(chunk).digest() != digest:
                        raise ChunkError()
                    else:
                        self._terminal.handle(chunk)
            except ChunkError:
                pass
            self._quit.set()


class TTYServer(TTYHandler):

    def __init__(self, manager: Protocol):
        TTYHandler.__init__(self, manager)
        self._states[self.ST_VERSION].upgrade(SyncCallable(self._check_version))
        self._sessions[self.SESH_UPSTREAM][1]["check"] = AsyncCallable(self._receive_chunks)
        self._sessions[self.SESH_DOWNSTREAM][1]["check"] = AsyncCallable(self._send_chunks)

        self._screen = None
        self._stream = None
        self._shell = None

    def _check_version(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Negotiate protocol version."""
        return ConfirmCode.YES if value == TERMINAL_VERSION else ConfirmCode.NO

    async def _receive_chunks(self, state: NetworkState, sesh: UpstreamIterator) -> int:
        """Prepare DownloadIterator with file information and chunk count."""
        self._shell = Shell()
        self._screen = TTYScreen(80, 24, self._shell)
        self._screen.set_mode(LNM)
        self._stream = ByteStream()
        self._stream.attach(self._screen)

        sesh.source(self)
        return ConfirmCode.YES

    async def _send_chunks(self, state: NetworkState, sesh: DownstreamIterator) -> int:
        """Prepare UploadIterator with file information and chunk count."""
        sesh.source(self._seq)
        self._idle = asyncio.create_task(self._idler())
        return ConfirmCode.YES

    def handle(self, data: bytes):
        """Receive input from client, process and send output screen information."""
        self._stream.feed(data)

        lines = self._screen.display
        for y in self._screen.dirty:
            self.send(msgpack.packb(
                {"type": "row", "y": y, "row": lines[y].rstrip()}, use_bin_type=True))

        cursor = self._screen.cursor
        self.send(msgpack.packb({"type": "cursor", "cursor": (cursor.x, cursor.y)}, use_bin_type=True))

        self._screen.dirty.clear()
