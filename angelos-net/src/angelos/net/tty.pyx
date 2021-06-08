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
# https://github.com/helgefmi/ansiterm/blob/master/ansiterm.py
import asyncio
import hashlib
import sys
import typing

import msgpack
from angelos.bin.term import print_line, Terminal
from angelos.common.misc import SyncCallable, AsyncCallable, SharedResource, shared
from angelos.net.base import Handler, StateMode, Protocol, PullChunkIterator, PushChunkIterator, ChunkError, \
    NetworkState, ConfirmCode, ProtocolNegotiationError, NetworkSession, NetworkIterator, ErrorCode

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


class TerminalClient:
    """Client side terminal emulator."""

    def __init__(self, client: "TTYClient"):
        self._client = client
        self._x = 1
        self._y = 1

    async def handle(self, data: bytes):
        """Receive terminal output information."""
        info = msgpack.unpackb(data, raw=False)
        if isinstance(info, dict):
            if info["type"] == "cursor":
                self._x = info["cursor"][0]
                self._y = info["cursor"][1]
                sys.stdout.write("\x1b[{};{}H".format(self._y, self._x))

            if info["type"] == "row":
                line = "\x1b[{};{}H{}".format(
                    info["y"], info["begin"],
                    print_line(info["y"], info["begin"], info["end"], info["row"]).decode(),
                )
                sys.stdout.write(line)
                # print(line)
                # print(print_line(info["y"], info["begin"], info["end"], info["row"]))

    def send(self, data: bytes):
        """Send text and sequences to server."""
        self._client.send(msgpack.packb({"type": "seq", "data": data}, use_bin_type=True))

    def resize(self, cols: int, lines: int):
        """Resize terminal window at server."""
        self._client.send(msgpack.packb({"type": "resize", "cols": cols, "lines": lines}, use_bin_type=True))


class TerminalServer(SharedResource, Terminal):
    """Pseudo terminal with sync."""

    def __init__(self, cols: int = 80, lines: int = 24):
        # super().__init__(cols=cols, lines=lines)
        SharedResource.__init__(self)
        Terminal.__init__(self, cols, lines)

    def display(self, sender: typing.Callable) -> None:
        for y, b, e, d in self._display():
            sender(y, b, e, d)
        self._clear()

    @shared
    def smear(self) -> None:
        self._smear()

    @shared
    def clear(self) -> None:
        self._clear()

    @shared
    def feed(self, data: bytes) -> None:
        self._feed(data)

    @shared
    def resize(self, lines: int, cols: int) -> None:
        self._resize(lines, cols)
        self._smear()


TERMINAL_VERSION = b"tty-0.1"

SESH_TYPE_DOWNSTREAM = 0x01
SESH_TYPE_UPSTREAM = 0x02


class TerminalResizeError(RuntimeError):
    """Terminal window new size refused."""


class DownstreamIterator(PullChunkIterator):
    """Test stub iterator item push with states."""

    ST_SIZE = 0x02

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PullChunkIterator.__init__(self, handler, server, SESH_TYPE_DOWNSTREAM, session, dict(), 0, check)
        self._queue = None

    async def pull_chunk(self) -> typing.Tuple[bytes, bytes]:
        """Pull chunk from queue on server and send it."""
        chunk = await self._queue.get()
        self._queue.task_done()
        return chunk, hashlib.sha1(chunk).digest()

    def source(self, queue: asyncio.Queue):
        """Set server chunk queue."""
        self._queue = queue


class UpstreamIterator(PushChunkIterator):
    """Test stub iterator item push with states."""

    ST_SIZE = 0x02

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PushChunkIterator.__init__(self, handler, server, SESH_TYPE_UPSTREAM, session, dict(), 0, check)
        self._tty = None

    async def push_chunk(self, chunk: bytes, digest: bytes):
        """Handle pushed chunk from client."""
        if hashlib.sha1(chunk).digest() != digest:
            raise ChunkError()
        await self._tty.handle(chunk)

    def source(self, tty: "TTYServer"):
        """Set chunk handle callable."""
        self._tty = tty


class TTYHandler(Handler):
    LEVEL = 1
    RANGE = 4

    ST_VERSION = 0x01
    ST_SIZE = 0x02

    SESH_DOWNSTREAM = SESH_TYPE_DOWNSTREAM
    SESH_UPSTREAM = SESH_TYPE_UPSTREAM

    def __init__(self, manager: Protocol):
        Handler.__init__(self, manager, states={
            self.ST_VERSION: (StateMode.MEDIATE, TERMINAL_VERSION),
            self.ST_SIZE: (StateMode.ONCE, b""),
        },
         sessions={
             self.SESH_DOWNSTREAM: (DownstreamIterator, dict()),
             self.SESH_UPSTREAM: (UpstreamIterator, dict()),
         }, max_sesh=2)
        self._quit = asyncio.Event()
        self._seq = asyncio.Queue()
        self._idle = None

    async def _idler(self):
        while not self._quit.is_set():
            self._seq.put_nowait(msgpack.packb({"type": "seq", "data": b"\x00"}, use_bin_type=True))
            await asyncio.sleep(.5)

    def send(self, data: bytes):
        """Send commands to PTY."""
        self._seq.put_nowait(data)


class TTYClient(TTYHandler):

    def __init__(self, manager: Protocol):
        TTYHandler.__init__(self, manager)
        self._up = None
        self._down = None
        self._terminal = None

    async def pty(self, cols: int = 80, lines: int = 24) -> TerminalClient:
        """Start a new PTY session."""
        await self._manager.ready()

        version = await self._call_mediate(self.ST_VERSION, [TERMINAL_VERSION])
        if version is None:
            raise ProtocolNegotiationError()

        self._states[self.ST_SIZE].update("{cols};{lines}".format(cols=cols, lines=lines).encode())
        resize = await self._call_tell(self.ST_SIZE)
        if not resize:
            raise TerminalResizeError()

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
            self._seq.task_done()
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
                        await self._terminal.handle(chunk)
            except ChunkError:
                pass
            except KeyError:
                self._manager.error(ErrorCode.MALFORMED, self._pkt_type + self._r_start, self.LEVEL)
            self._quit.set()


class TTYServer(TTYHandler):

    def __init__(self, manager: Protocol):
        TTYHandler.__init__(self, manager)
        self._states[self.ST_VERSION].upgrade(SyncCallable(self._check_version))
        self._sessions[self.SESH_UPSTREAM][1]["check"] = AsyncCallable(self._receive_chunks)
        self._sessions[self.SESH_DOWNSTREAM][1]["check"] = AsyncCallable(self._send_chunks)

        self._resize_timer = None
        self._display_task = None
        self._terminal = None
        self._lock = asyncio.Lock()

    def _check_version(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Negotiate protocol version."""
        return ConfirmCode.YES if value == TERMINAL_VERSION else ConfirmCode.NO

    async def _receive_chunks(self, state: NetworkState, sesh: UpstreamIterator) -> int:
        """Prepare DownloadIterator with file information and chunk count."""
        cols, lines = self._states[self.ST_SIZE].value.split(b";")
        cols = max(80, min(240, int(cols)))
        lines = max(8, min(72, int(lines)))

        self._terminal = TerminalServer(cols, lines)
        await self._terminal.smear()

        sesh.source(self)
        return ConfirmCode.YES

    async def _send_chunks(self, state: NetworkState, sesh: DownstreamIterator) -> int:
        """Prepare UploadIterator with file information and chunk count."""
        sesh.source(self._seq)
        if self._terminal:
            self._display_task = asyncio.create_task(self._display_later())
        self._idle = asyncio.create_task(self._idler())
        return ConfirmCode.YES

    def _display(self, y: int, b: int, e: int, d: bytes):
        """Send display update to client."""
        self.send(msgpack.packb(
            {"type": "row", "y": y, "begin": b, "end": e, "row": d}, use_bin_type=True))

    async def handle(self, data: bytes):
        """Receive input from client, process and send output screen information."""
        info = msgpack.unpackb(data, raw=False)
        if isinstance(info, dict) and self._terminal:
            try:
                if info["type"] == "seq":
                    async with self._lock:
                        await self._terminal.feed(info["data"])
                        self.send(msgpack.packb(
                            {"type": "cursor", "cursor": (self._terminal.x, self._terminal.y)}, use_bin_type=True))
                        self._terminal.display(self._display)
                if info["type"] == "resize":
                    if self._resize_timer:
                        self._resize_timer.cancel()
                    self._resize_timer = asyncio.create_task(
                        self._resize_later(max(80, min(240, info["cols"])), max(8, min(72, info["lines"])))
                    )
            except KeyError:
                self._manager.error(ErrorCode.MALFORMED, self._pkt_type + self._r_start, self.LEVEL)

    async def _resize_later(self, cols: int, lines: int):
        await asyncio.sleep(.25)
        async with self._lock:
            await self._terminal.resize(lines, cols)
            self._terminal.display(self._display)
        self._resize_timer = None

    async def _display_later(self):
        async with self._lock:
            self._terminal.display(self._display)
        self._display_task = None
