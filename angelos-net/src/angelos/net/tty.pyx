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
import typing

import msgpack
from angelos.common.misc import SyncCallable, AsyncCallable
from angelos.net.base import Handler, StateMode, Protocol, PullChunkIterator, PushChunkIterator, ChunkError, \
    NetworkState, ConfirmCode, ProtocolNegotiationError, NetworkSession, NetworkIterator, ErrorCode
from angelos.net.pyte import HistoryScreen, LNM, ByteStream
from angelos.net.shell import Shell

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
        self._x = 0
        self._y = 0

    def handle(self, data: bytes):
        """Receive terminal output information."""
        info = msgpack.unpackb(data, raw=False)
        if isinstance(info, dict):
            if info["type"] == "cursor":
                self._x = info["cursor"][0]
                self._y = info["cursor"][1]
                print("\x1b[{};{}H".format(self._y, self._x))
            if info["type"] == "row":
                line = "\x1b[{};0H{}\x1b[{};{}H".format(info["y"], info["row"], self._y, self._x)
                print(line.rstrip())

    def send(self, data: bytes):
        """Send text and sequences to server."""
        self._client.send(msgpack.packb({"type": "seq", "data": data}, use_bin_type=True))

    def resize(self, cols: int, lines: int):
        """Resize terminal window at server."""
        self._client.send(msgpack.packb(
            {"type": "resize", "cols": cols, "lines": lines}, use_bin_type=True))


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
                        self._terminal.handle(chunk)
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

        self._screen = None
        self._stream = None
        self._shell = None

    def _check_version(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Negotiate protocol version."""
        return ConfirmCode.YES if value == TERMINAL_VERSION else ConfirmCode.NO

    async def _receive_chunks(self, state: NetworkState, sesh: UpstreamIterator) -> int:
        """Prepare DownloadIterator with file information and chunk count."""
        cols, lines = self._states[self.ST_SIZE].value.split(b";")
        cols = max(80, min(240, int(cols)))
        lines = max(8, min(72, int(lines)))

        self._shell = Shell()
        self._screen = TTYScreen(cols, lines, self._shell)
        self._screen.set_mode(LNM)
        self._stream = ByteStream()
        self._stream.attach(self._screen)

        sesh.source(self)
        return ConfirmCode.YES

    async def _send_chunks(self, state: NetworkState, sesh: DownstreamIterator) -> int:
        """Prepare UploadIterator with file information and chunk count."""
        sesh.source(self._seq)
        asyncio.get_event_loop().call_soon(self._display)
        self._idle = asyncio.create_task(self._idler())
        return ConfirmCode.YES

    def _display(self):
        """Send display update to client."""
        for y in range(self._screen.columns):
            self.send(msgpack.packb(
                {"type": "row", "y": y, "row": self._screen.render_line(y).rstrip()}, use_bin_type=True))

    def handle(self, data: bytes):
        """Receive input from client, process and send output screen information."""
        info = msgpack.unpackb(data, raw=False)
        if isinstance(info, dict):
            try:
                if info["type"] == "seq":
                    self._stream.feed(info["data"])
                    cursor = self._screen.cursor
                    self.send(msgpack.packb({"type": "cursor", "cursor": (cursor.x, cursor.y)}, use_bin_type=True))
                    for y in self._screen.dirty:
                        self.send(msgpack.packb(
                            {"type": "row", "y": y, "row": self._screen.render_line(y).rstrip()}, use_bin_type=True))
                    self._screen.dirty.clear()

                if info["type"] == "resize":
                    if self._screen:
                        if self._resize_timer:
                            self._resize_timer.cancel()
                        self._resize_timer = asyncio.get_event_loop().call_later(
                            .25, self._resize_later, max(80, min(240, info["cols"])), max(8, min(72, info["lines"])))
            except KeyError:
                self._manager.error(ErrorCode.MALFORMED, self._pkt_type + self._r_start, self.LEVEL)

    def _resize_later(self, cols: int, lines: int):
        self._screen.resize(lines, cols)
        self._display()
        self._resize_timer = None


class BaseShell:
    """Shell base class that handles input and writes output."""

    SEQUENCES = (
        b"\n", b"\r", b"\x1bOM", b"\x04", b"\x08", b"\x7f", b"\x1b[3~", b"\x15", b"\x0b", b"\x10", b"\x1b[A",
        b"\x1bOA", b"\x0e", b"\x1b[B", b"\x1bOB", b"\x02", b"\x1b[D", b"\x1bOD", b"\x06", b"\x1b[C", b"\x1bOC",
        b"\x01", b"\x1b[H", b"\x1b[1~", b"\x05", b"\x1b[F", b"\x1b[4~", b"\x12", b"\x19",  b"\x03", b"\x1b[33~"
    )

    def _end_line(self):
        pass

    def _eof_or_delete(self):
        pass

    def _erase_left(self):
        pass

    def _erase_right(self):
        pass

    def _erase_line(self):
        pass

    def _erase_to_end(self):
        pass

    def _history_prev(self):
        pass

    def _history_next(self):
        pass

    def _move_left(self):
        pass

    def _move_right(self):
        pass

    def _move_to_start(self):
        pass

    def _move_to_end(self):
        pass

    def _redraw(self):
        pass

    def _insert_erased(self):
        pass

    def _send_break(self):
        pass

    def _print(self, chr: str):
        pass

    KEY_MAP = {
        b"\n": _end_line,  b"\r": _end_line, b"\x1bOM": _end_line,
        b"\x04": _eof_or_delete,
        b"\x08": _erase_left, b"\x7f": _erase_left,
        b"\x1b[3~": _erase_right,
        b"\x15": _erase_line,
        b"\x0b": _erase_to_end,
        b"\x10": _history_prev, b"\x1b[A": _history_prev, b"\x1bOA": _history_prev,
        b"\x0e": _history_next, b"\x1b[B": _history_next, b"\x1bOB": _history_next,
        b"\x02": _move_left, b"\x1b[D": _move_left, b"\x1bOD": _move_left,
        b"\x06": _move_right, b"\x1b[C": _move_right, b"\x1bOC": _move_right,
        b"\x01": _move_to_start, b"\x1b[H": _move_to_start, b"\x1b[1~": _move_to_start,
        b"\x05": _move_to_end, b"\x1b[F": _move_to_end, b"\x1b[4~": _move_to_end,
        b"\x12": _redraw,
        b"\x19": _insert_erased,
        b"\x03": _send_break, b"\x1b[33~": _send_break
    }

    def feed(self, data: bytes):
        """Printable characters are printed, others are executed."""
        if data in self.KEY_MAP.keys():
            self.KEY_MAP[data]()
        else:
            value = data.decode()[0]
            if value.isprintable():
                self._print(value)