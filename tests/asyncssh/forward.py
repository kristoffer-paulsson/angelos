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

"""SSH port forwarding handlers"""

import asyncio
import socket

from .misc import ChannelOpenError


class SSHForwarder:
    """SSH port forwarding connection handler"""

    def __init__(self, peer=None):
        self._peer = peer
        self._transport = None
        self._inpbuf = b''
        self._eof_received = False

        if peer:
            peer.set_peer(self)

    def set_peer(self, peer):
        """Set the peer forwarder to exchange data with"""

        self._peer = peer

    def write(self, data):
        """Write data to the transport"""

        self._transport.write(data)

    def write_eof(self):
        """Write end of file to the transport"""

        try:
            self._transport.write_eof()
        except OSError: # pragma: no cover
            pass

    def was_eof_received(self):
        """Return whether end of file has been received or not"""

        return self._eof_received

    def pause_reading(self):
        """Pause reading from the transport"""

        self._transport.pause_reading()

    def resume_reading(self):
        """Resume reading on the transport"""

        self._transport.resume_reading()

    def connection_made(self, transport):
        """Handle a newly opened connection"""

        self._transport = transport

        sock = transport.get_extra_info('socket')
        if sock.family in {socket.AF_INET, socket.AF_INET6}:
            sock.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)

    def connection_lost(self, exc):
        """Handle an incoming connection close"""

        # pylint: disable=unused-argument

        self.close()

    def session_started(self):
        """Handle session start"""

    def data_received(self, data, datatype=None):
        """Handle incoming data from the transport"""

        # pylint: disable=unused-argument

        if self._peer:
            self._peer.write(data)
        else:
            self._inpbuf += data

    def eof_received(self):
        """Handle an incoming end of file from the transport"""

        self._eof_received = True

        if self._peer:
            self._peer.write_eof()

            return not self._peer.was_eof_received()
        else:
            return True

    def pause_writing(self):
        """Pause writing by asking peer to pause reading"""

        self._peer.pause_reading()

    def resume_writing(self):
        """Resume writing by asking peer to resume reading"""

        self._peer.resume_reading()

    def close(self):
        """Close this port forwarder"""

        if self._transport:
            self._transport.close()
            self._transport = None

        if self._peer:
            peer = self._peer
            self._peer = None
            peer.close()


class SSHLocalForwarder(SSHForwarder):
    """Local forwarding connection handler"""

    def __init__(self, conn, coro):
        super().__init__()
        self._conn = conn
        self._coro = coro

    @asyncio.coroutine
    def _forward(self, *args):
        """Begin local forwarding"""

        def session_factory():
            """Return an SSH forwarder"""

            return SSHForwarder(self)

        try:
            yield from self._coro(session_factory, *args)
        except ChannelOpenError as exc:
            self.connection_lost(exc)
            return

        if self._inpbuf:
            self._peer.write(self._inpbuf)
            self._inpbuf = b''

        if self._eof_received:
            self._peer.write_eof()

    def forward(self, *args):
        """Start a task to begin local forwarding"""

        self._conn.create_task(self._forward(*args))


class SSHLocalPortForwarder(SSHLocalForwarder):
    """Local TCP port forwarding connection handler"""

    def connection_made(self, transport):
        """Handle a newly opened connection"""

        super().connection_made(transport)

        orig_host, orig_port = transport.get_extra_info('peername')[:2]
        self.forward(orig_host, orig_port)


class SSHLocalPathForwarder(SSHLocalForwarder):
    """Local UNIX domain socket forwarding connection handler"""

    def connection_made(self, transport):
        """Handle a newly opened connection"""

        super().connection_made(transport)
        self.forward()
