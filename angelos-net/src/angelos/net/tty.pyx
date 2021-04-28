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
import typing
from angelos.common.misc import SyncCallable, AsyncCallable
from angelos.net.base import Handler, StateMode, Protocol, PullChunkIterator, PushChunkIterator, ChunkError, \
    NetworkState, ConfirmCode, ProtocolNegotiationError, NetworkSession, NetworkIterator
from angelos.net.pyte import HistoryScreen, LNM, ByteStream

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


class Terminal:

    TTY_SEQ = b"""(\x1B\[[\x20-\x2F]*[\x30-\x7E]|\x1B[\x20-\x2F]*[\x40-\x7E]|[\x00-\x1F])"""

    def __init__(self):
        self._regex = re.compile(self.TTY_SEQ)

    def handle(self, data: bytes):
        """Receive data that parses and then is handled by sequencer."""
        while bool(data):
            parsed, data, seq = self.parse(data)
            if seq:
                self._sequence(parsed)
            else:
                self._text(parsed)

    def parse(self, data: bytes):
        """Parses incoming text for control and escape sequences.
        Returns a tuple of text/sequence, rest thereof and bool to indicate if first is sequence.

        (str, str, bool)
        """
        match = self._regex.search(data)
        if not match:
            return data, b"", False
        elif match:
            groups = match.groups()
            if match.start() == 0:
                return groups[0], data[match.end():], True
            else:
                return data[match.pos: match.start()], data[match.start(): match.endpos], False

    def send(self, data: bytes):
        """Send data and sequences to other side."""

    def _sequence(self, seq: bytes):
        if seq != b"\x00":
            print("SEQ", seq)

    def _text(self, text: bytes):
        print("TEXT", text)


class TerminalClient(Terminal):
    """Client side terminal emulator."""

    def __init__(self, client: "TTYClient"):
        Terminal.__init__(self)
        self._client = client

    def send(self, data: bytes):
        """Send text and sequences to server."""
        self._client.send(data)


class TerminalServer(Terminal):
    """Server side terminal emulator."""

    def __init__(self, server: "TTYServer"):
        Terminal.__init__(self)
        self._server = server

        self._screen = None
        self._stream = None

    def setup(self, columns: int, lines: int, p_in):
        self._screen = HistoryScreen(columns, lines)
        self._screen.set_mode(LNM)
        # Set the input to the shell.
        # self._screen.write_process_input = lambda data: p_in.write(data.encode())
        self._stream = ByteStream()
        self._stream.attach(self._screen)

    def handle(self, data: bytes):
        """Receive data that parses and then is handled by sequencer."""
        self._stream.feed(data)

    def send(self, data: bytes):
        """Send text and sequences to client."""
        self._server.send(data)

    def feed(self, data):


    def dumps(self):
        cursor = self._screen.cursor
        lines = []
        for y in self._screen.dirty:
            line = self._screen.buffer[y]
            data = [(c.data, c.reverse, c.fg, c.bg) for c in (line[x] for x in range(self._screen.columns))]
            lines.append((y, data))

        self._screen.dirty.clear()
        return json.dumps({"c": (cursor.x, cursor.y), "lines": lines})



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
        self._teminal = None

    async def push_chunk(self, chunk: bytes, digest: bytes):
        """Handle pushed chunk from client."""
        if hashlib.sha1(chunk).digest() != digest:
            raise ChunkError()
        self._terminal.handle(chunk)

    def source(self, terminal: TerminalServer):
        """Set chunk handle callable."""
        self._terminal = terminal


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
        self._terminal = TerminalServer(self)

    def _check_version(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Negotiate protocol version."""
        return ConfirmCode.YES if value == TERMINAL_VERSION else ConfirmCode.NO

    async def _receive_chunks(self, state: NetworkState, sesh: UpstreamIterator) -> int:
        """Prepare DownloadIterator with file information and chunk count."""
        sesh.source(self._terminal)
        return ConfirmCode.YES

    async def _send_chunks(self, state: NetworkState, sesh: DownstreamIterator) -> int:
        """Prepare UploadIterator with file information and chunk count."""
        sesh.source(self._seq)
        self._idle = asyncio.create_task(self._idler())
        return ConfirmCode.YES
