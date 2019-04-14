# Copyright (c) 2013-2018 by Ron Frederick <ronf@timeheart.net> and others.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License v2.0 which accompanies this
# distribution and is available at:
#
#     http://www.eclipse.org/legal/epl-2.0/
#
# This program may also be made available under the following secondary
# licenses when the conditions for such availability set forth in the
# Eclipse Public License v2.0 are satisfied:
#
#    GNU General Public License, Version 2.0, or any later versions of
#    that license
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0-or-later
#
# Contributors:
#     Ron Frederick - initial implementation, API, and documentation

"""SSH stream handlers"""

import asyncio
import re

from .constants import EXTENDED_DATA_STDERR
from .misc import BreakReceived, SignalReceived
from .misc import SoftEOFReceived, TerminalSizeChanged
from .misc import async_iterator, python35
from .session import SSHClientSession, SSHServerSession
from .session import SSHTCPSession, SSHUNIXSession
from .sftp import run_sftp_server
from .scp import run_scp_server

_NEWLINE = object()


class SSHReader:
    """SSH read stream handler"""

    def __init__(self, session, chan, datatype=None):
        self._session = session
        self._chan = chan
        self._datatype = datatype

    if python35:
        @async_iterator
        def __aiter__(self):
            """Allow SSHReader to be an async iterator"""

            return self

        @asyncio.coroutine
        def __anext__(self):
            """Return one line at a time when used as an async iterator"""

            line = yield from self.readline()

            if line:
                return line
            else:
                raise StopAsyncIteration

    @property
    def channel(self):
        """The SSH channel associated with this stream"""

        return self._chan

    @property
    def logger(self):
        """The SSH logger associated with this stream"""

        return self._chan.logger

    def get_extra_info(self, name, default=None):
        """Return additional information about this stream

           This method returns extra information about the channel
           associated with this stream. See :meth:`get_extra_info()
           <SSHClientChannel.get_extra_info>` on :class:`SSHClientChannel`
           for additional information.

        """

        return self._chan.get_extra_info(name, default)

    @asyncio.coroutine
    def read(self, n=-1):
        """Read data from the stream

           This method is a coroutine which reads up to `n` bytes
           or characters from the stream. If `n` is not provided or
           set to `-1`, it reads until EOF or a signal is received.

           If EOF is received and the receive buffer is empty, an
           empty `bytes` or `str` object is returned.

           If the next data in the stream is a signal, the signal is
           delivered as a raised exception.

           .. note:: Unlike traditional `asyncio` stream readers,
                     the data will be delivered as either `bytes` or
                     a `str` depending on whether an encoding was
                     specified when the underlying channel was opened.

        """

        return self._session.read(n, self._datatype, exact=False)

    @asyncio.coroutine
    def readline(self):
        """Read one line from the stream

           This method is a coroutine which reads one line, ending in
           `'\\n'`.

           If EOF is received before `'\\n'` is found, the partial
           line is returned. If EOF is received and the receive buffer
           is empty, an empty `bytes` or `str` object is returned.

           If the next data in the stream is a signal, the signal is
           delivered as a raised exception.

           .. note:: In Python 3.5 and later, :class:`SSHReader` objects
                     can also be used as async iterators, returning input
                     data one line at a time.

        """

        try:
            return (yield from self.readuntil(_NEWLINE))
        except asyncio.IncompleteReadError as exc:
            return exc.partial

    @asyncio.coroutine
    def readuntil(self, separator):
        """Read data from the stream until `separator` is seen

           This method is a coroutine which reads from the stream until
           the requested separator is seen. If a match is found, the
           returned data will include the separator at the end.

           The separator argument can be either a single `bytes` or
           `str` value or a sequence of multiple values to match
           against, returning data as soon as any of the separators
           are found in the stream.

           If EOF or a signal is received before a match occurs, an
           :exc:`IncompleteReadError <asyncio.IncompleteReadError>`
           is raised and its `partial` attribute will contain the
           data in the stream prior to the EOF or signal.

           If the next data in the stream is a signal, the signal is
           delivered as a raised exception.

        """

        return self._session.readuntil(separator, self._datatype)

    @asyncio.coroutine
    def readexactly(self, n):
        """Read an exact amount of data from the stream

           This method is a coroutine which reads exactly n bytes or
           characters from the stream.

           If EOF or a signal is received in the stream before `n`
           bytes are read, an :exc:`IncompleteReadError
           <asyncio.IncompleteReadError>` is raised and its `partial`
           attribute will contain the data before the EOF or signal.

           If the next data in the stream is a signal, the signal is
           delivered as a raised exception.

        """

        return self._session.read(n, self._datatype, exact=True)

    def at_eof(self):
        """Return whether the stream is at EOF

           This method returns `True` when EOF has been received and
           all data in the stream has been read.

        """

        return self._session.at_eof(self._datatype)

    def get_redirect_info(self):
        """Get information needed to redirect from this SSHReader"""

        return self._session, self._datatype


class SSHWriter:
    """SSH write stream handler"""

    def __init__(self, session, chan, datatype=None):
        self._session = session
        self._chan = chan
        self._datatype = datatype

    @property
    def channel(self):
        """The SSH channel associated with this stream"""

        return self._chan

    @property
    def logger(self):
        """The SSH logger associated with this stream"""

        return self._chan.logger

    def get_extra_info(self, name, default=None):
        """Return additional information about this stream

           This method returns extra information about the channel
           associated with this stream. See :meth:`get_extra_info()
           <SSHClientChannel.get_extra_info>` on :class:`SSHClientChannel`
           for additional information.

        """

        return self._chan.get_extra_info(name, default)

    def can_write_eof(self):
        """Return whether the stream supports :meth:`write_eof`"""

        return self._chan.can_write_eof()

    def close(self):
        """Close the channel

           .. note:: After this is called, no data can be read or written
                     from any of the streams associated with this channel.

        """

        return self._chan.close()

    @asyncio.coroutine
    def drain(self):
        """Wait until the write buffer on the channel is flushed

           This method is a coroutine which blocks the caller if the
           stream is currently paused for writing, returning when
           enough data has been sent on the channel to allow writing
           to resume. This can be used to avoid buffering an excessive
           amount of data in the channel's send buffer.

        """

        return (yield from self._session.drain(self._datatype))

    def write(self, data):
        """Write data to the stream

           This method writes bytes or characters to the stream.

           .. note:: Unlike traditional `asyncio` stream writers,
                     the data must be supplied as either `bytes` or
                     a `str` depending on whether an encoding was
                     specified when the underlying channel was opened.

        """

        return self._chan.write(data, self._datatype)

    def writelines(self, list_of_data):
        """Write a collection of data to the stream"""

        return self._chan.writelines(list_of_data, self._datatype)

    def write_eof(self):
        """Write EOF on the channel

           This method sends an end-of-file indication on the channel,
           after which no more data can be written.

           .. note:: On an :class:`SSHServerChannel` where multiple
                     output streams are created, writing EOF on one
                     stream signals EOF for all of them, since it
                     applies to the channel as a whole.

        """

        return self._chan.write_eof()

    def get_redirect_info(self):
        """Get information needed to redirect to this SSHWriter"""

        return self._session, self._datatype


class SSHStreamSession:
    """SSH stream session handler"""

    def __init__(self):
        self._chan = None
        self._conn = None
        self._encoding = None
        self._errors = 'strict'
        self._loop = None
        self._limit = None
        self._exception = None
        self._eof_received = False
        self._connection_lost = False
        self._recv_buf = {None: []}
        self._recv_buf_len = 0
        self._read_locks = {None: asyncio.Lock(loop=self._loop)}
        self._read_waiters = {None: None}
        self._read_paused = False
        self._write_paused = False
        self._drain_waiters = {None: set()}

    @asyncio.coroutine
    def _block_read(self, datatype):
        """Wait for more data to arrive on the stream"""

        try:
            waiter = asyncio.Future(loop=self._loop)
            self._read_waiters[datatype] = waiter
            yield from waiter
        finally:
            self._read_waiters[datatype] = None

    def _unblock_read(self, datatype):
        """Signal that more data has arrived on the stream"""

        waiter = self._read_waiters[datatype]
        if waiter and not waiter.done():
            waiter.set_result(None)

    def _should_block_drain(self, datatype):
        """Return whether output is still being written to the channel"""

        # pylint: disable=unused-argument

        return self._write_paused and not self._connection_lost

    def _unblock_drain(self, datatype):
        """Signal that more data can be written on the stream"""

        if not self._should_block_drain(datatype):
            for waiter in self._drain_waiters[datatype]:
                if not waiter.done(): # pragma: no branch
                    waiter.set_result(None)

    def _should_pause_reading(self):
        """Return whether to pause reading from the channel"""

        return self._limit and self._recv_buf_len >= self._limit

    def _maybe_pause_reading(self):
        """Pause reading if necessary"""

        if not self._read_paused and self._should_pause_reading():
            self._read_paused = True
            self._chan.pause_reading()
            return True
        else:
            return False

    def _maybe_resume_reading(self):
        """Resume reading if necessary"""

        if self._read_paused and not self._should_pause_reading():
            self._read_paused = False
            self._chan.resume_reading()
            return True
        else:
            return False

    def connection_made(self, chan):
        """Handle a newly opened channel"""

        self._chan = chan
        self._conn = chan.get_connection()
        self._encoding, self._errors = chan.get_encoding()
        self._loop = chan.get_loop()
        self._limit = self._chan.get_recv_window()

        for datatype in chan.get_read_datatypes():
            self._recv_buf[datatype] = []
            self._read_locks[datatype] = asyncio.Lock(loop=self._loop)
            self._read_waiters[datatype] = None

        for datatype in chan.get_write_datatypes():
            self._drain_waiters[datatype] = set()

    def connection_lost(self, exc):
        """Handle an incoming channel close"""

        self._connection_lost = True
        self._exception = exc

        if not self._eof_received:
            if exc:
                for datatype in self._read_waiters:
                    self._recv_buf[datatype].append(exc)

            self.eof_received()

        for datatype in self._drain_waiters:
            self._unblock_drain(datatype)

    def data_received(self, data, datatype):
        """Handle incoming data on the channel"""

        self._recv_buf[datatype].append(data)
        self._recv_buf_len += len(data)
        self._unblock_read(datatype)
        self._maybe_pause_reading()

    def eof_received(self):
        """Handle an incoming end of file on the channel"""

        self._eof_received = True

        for datatype in self._read_waiters:
            self._unblock_read(datatype)

        return True

    def at_eof(self, datatype):
        """Return whether end of file has been received on the channel"""

        return self._eof_received and not self._recv_buf[datatype]

    def pause_writing(self):
        """Handle a request to pause writing on the channel"""

        self._write_paused = True

    def resume_writing(self):
        """Handle a request to resume writing on the channel"""

        self._write_paused = False

        for datatype in self._drain_waiters:
            self._unblock_drain(datatype)

    @asyncio.coroutine
    def read(self, n, datatype, exact):
        """Read data from the channel"""

        recv_buf = self._recv_buf[datatype]
        buf = '' if self._encoding else b''
        data = []

        with (yield from self._read_locks[datatype]):
            while True:
                while recv_buf and n != 0:
                    if isinstance(recv_buf[0], Exception):
                        if data:
                            break
                        else:
                            exc = recv_buf.pop(0)

                            if isinstance(exc, SoftEOFReceived):
                                n = 0
                                break
                            else:
                                raise exc

                    l = len(recv_buf[0])
                    if n > 0 and l > n:
                        data.append(recv_buf[0][:n])
                        recv_buf[0] = recv_buf[0][n:]
                        self._recv_buf_len -= n
                        n = 0
                        break

                    data.append(recv_buf.pop(0))
                    self._recv_buf_len -= l
                    n -= l

                if self._maybe_resume_reading():
                    continue

                if n == 0 or (n > 0 and data and not exact) or \
                        (n < 0 and recv_buf) or self._eof_received:
                    break

                yield from self._block_read(datatype)

        buf = buf.join(data)
        if n > 0 and exact:
            raise asyncio.IncompleteReadError(buf, len(buf) + n)

        return buf

    @asyncio.coroutine
    def readuntil(self, separator, datatype):
        """Read data from the channel until a separator is seen"""

        if separator is _NEWLINE:
            separator = '\n' if self._encoding else b'\n'
        elif not separator:
            raise ValueError('Separator cannot be empty')

        if isinstance(separator, (str, bytes)):
            separators = [separator]
        else:
            separators = list(separator)

        seplen = max(len(sep) for sep in separators)
        bar = '|' if self._encoding else b'|'
        pat = re.compile(bar.join(map(re.escape, separators)))
        recv_buf = self._recv_buf[datatype]
        buf = '' if self._encoding else b''
        curbuf = 0
        buflen = 0

        with (yield from self._read_locks[datatype]):
            while True:
                while curbuf < len(recv_buf):
                    if isinstance(recv_buf[curbuf], Exception):
                        if buf:
                            recv_buf[:curbuf] = []
                            self._recv_buf_len -= buflen
                            raise asyncio.IncompleteReadError(buf, None)
                        else:
                            exc = recv_buf.pop(0)

                            if isinstance(exc, SoftEOFReceived):
                                return buf
                            else:
                                raise exc

                    buf += recv_buf[curbuf]
                    start = max(buflen + 1 - seplen, 0)

                    match = pat.search(buf, start)
                    if match:
                        idx = match.end()
                        recv_buf[:curbuf] = []
                        recv_buf[0] = buf[idx:]
                        buf = buf[:idx]
                        self._recv_buf_len -= idx

                        if not recv_buf[0]:
                            recv_buf.pop(0)

                        self._maybe_resume_reading()
                        return buf

                    buflen += len(recv_buf[curbuf])
                    curbuf += 1

                if self._read_paused or self._eof_received:
                    recv_buf[:curbuf] = []
                    self._recv_buf_len -= buflen
                    raise asyncio.IncompleteReadError(buf, None)

                yield from self._block_read(datatype)

    @asyncio.coroutine
    def drain(self, datatype):
        """Wait for data written to the channel to drain"""

        while self._should_block_drain(datatype):
            try:
                waiter = asyncio.Future(loop=self._loop)
                self._drain_waiters[datatype].add(waiter)
                yield from waiter
            finally:
                self._drain_waiters[datatype].remove(waiter)

        if self._connection_lost:
            exc = self._exception

            if not exc and self._write_paused:
                exc = BrokenPipeError()

            if exc:
                raise exc   # pylint: disable=raising-bad-type


class SSHClientStreamSession(SSHStreamSession, SSHClientSession):
    """SSH client stream session handler"""


class SSHServerStreamSession(SSHStreamSession, SSHServerSession):
    """SSH server stream session handler"""

    def __init__(self, session_factory, sftp_factory, allow_scp):
        super().__init__()

        self._session_factory = session_factory
        self._sftp_factory = sftp_factory
        self._allow_scp = allow_scp and bool(sftp_factory)

    def shell_requested(self):
        """Return whether a shell can be requested"""

        return bool(self._session_factory)

    def exec_requested(self, command):
        """Return whether execution of a command can be requested"""

        # Avoid incorrect pylint suggestion to use ternary
        # pylint: disable=consider-using-ternary

        return ((self._allow_scp and command.startswith('scp ')) or
                bool(self._session_factory))

    def subsystem_requested(self, subsystem):
        """Return whether starting a subsystem can be requested"""

        if subsystem == 'sftp':
            return bool(self._sftp_factory)
        else:
            return bool(self._session_factory)

    def session_started(self):
        """Start a session for this newly opened server channel"""

        command = self._chan.get_command()

        stdin = SSHReader(self, self._chan)
        stdout = SSHWriter(self, self._chan)
        stderr = SSHWriter(self, self._chan, EXTENDED_DATA_STDERR)

        if self._chan.get_subsystem() == 'sftp':
            self._chan.set_encoding(None)
            self._encoding = None

            handler = run_sftp_server(self._sftp_factory.new(self._chan),
                                      stdin, stdout)
        elif self._allow_scp and command and command.startswith('scp '):
            self._chan.set_encoding(None)
            self._encoding = None

            handler = run_scp_server(self._sftp_factory.new(self._chan),
                                     command, stdin, stdout, stderr)
        else:
            handler = self._session_factory(stdin, stdout, stderr)

        if asyncio.iscoroutine(handler):
            self._conn.create_task(handler, stdin.logger)

    def break_received(self, msec):
        """Handle an incoming break on the channel"""

        self._recv_buf[None].append(BreakReceived(msec))
        self._unblock_read(None)
        return True

    def signal_received(self, signal):
        """Handle an incoming signal on the channel"""

        self._recv_buf[None].append(SignalReceived(signal))
        self._unblock_read(None)

    def soft_eof_received(self):
        """Handle an incoming soft EOF on the channel"""

        self._recv_buf[None].append(SoftEOFReceived())
        self._unblock_read(None)

    def terminal_size_changed(self, width, height, pixwidth, pixheight):
        """Handle an incoming terminal size change on the channel"""

        self._recv_buf[None].append(TerminalSizeChanged(width, height,
                                                        pixwidth, pixheight))
        self._unblock_read(None)


class SSHSocketStreamSession(SSHStreamSession):
    """Socket stream session handler"""

    def __init__(self, handler_factory=None):
        super().__init__()

        self._handler_factory = handler_factory

    def session_started(self):
        """Start a session for this newly opened socket channel"""

        if self._handler_factory:
            reader = SSHReader(self, self._chan)
            writer = SSHWriter(self, self._chan)

            handler = self._handler_factory(reader, writer)

            if asyncio.iscoroutine(handler):
                self._conn.create_task(handler, reader.logger)


class SSHTCPStreamSession(SSHSocketStreamSession, SSHTCPSession):
    """TCP stream session handler"""


class SSHUNIXStreamSession(SSHSocketStreamSession, SSHUNIXSession):
    """UNIX stream session handler"""
