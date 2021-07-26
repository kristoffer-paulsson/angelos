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
import asyncio
import errno
import os
from abc import abstractmethod

from asyncssh import ConnectionLost, Error, FX_FAILURE, FX_BAD_MESSAGE, FX_NO_CONNECTION, DEFAULT_LANG, FXP_EXTENDED, \
    FXP_STATUS, FXP_INIT, FXP_VERSION, FX_OK, FXP_HANDLE, FXP_DATA, FXP_NAME, FX_EOF, FX_OP_UNSUPPORTED, \
    FX_NO_SUCH_FILE, FX_PERMISSION_DENIED
from asyncssh.connection import SSHConnection
from asyncssh.misc import to_hex
from asyncssh.packet import SSHPacketLogger, SSHPacket, Byte, UInt32, PacketDecodeError, String
from angelos.lib.ioc import ContainerAware

_VERSION = 0


class Failure(Error):
    """Failure."""
    def __init__(self, reason, lang=DEFAULT_LANG):
        super().__init__(FX_FAILURE, reason, lang)


class BadMessage(Error):
    """Bad message."""
    def __init__(self, reason, lang=DEFAULT_LANG):
        super().__init__(FX_BAD_MESSAGE, reason, lang)


class NoConnection(Error):
    """No connection."""
    def __init__(self, reason, lang=DEFAULT_LANG):
        super().__init__(FX_NO_CONNECTION, reason, lang)


class OpUnsupported(Error):
    """Operation unsupported."""
    def __init__(self, reason, lang=DEFAULT_LANG):
        super().__init__(FX_OP_UNSUPPORTED, reason, lang)


class SubsytemHandler(SSHPacketLogger):
    """Session handler"""

    _data_packet_types = {
        # FXP_WRITE, FXP_DATA
    }

    _return_types = {
        # FXP_OPEN: FXP_HANDLE,
    }

    def __init__(self, reader, writer):
        self._reader = reader
        self._writer = writer

        self._logger = reader.logger.get_child('sftp')

    @property
    def logger(self):
        """A logger associated with this SFTP handler"""

        return self._logger

    async def _cleanup(self):
        """Clean up this session"""
        if self._writer:  # pragma: no branch
            self._writer.close()
            self._reader = None
            self._writer = None

    @abstractmethod
    async def _process_packet(self, packet_type, packet_id, packet):
        """Abstract method for processing packets"""

        raise NotImplementedError

    def send_packet(self, packet_type, packet_id, *args):
        """Send a packet"""
        payload = Byte(packet_type) + b"".join(args)

        try:
            self._writer.write(UInt32(len(payload)) + payload)
        except ConnectionError as exc:
            raise ConnectionLost(str(exc)) from None

        self.log_sent_packet(packet_type, packet_id, payload)

    async def receive_packet(self) -> SSHPacket:
        """Receive an SFTP packet"""
        packet_length = int.from_bytes(await self._reader.readexactly(4), 'big')
        packet = await self._reader.readexactly(packet_length)
        return SSHPacket(packet)

    async def receive_packets(self):
        """Receive and process packets"""
        try:
            while self._reader:
                packet = await self.receive_packet()

                packet_type = packet.get_byte()
                packet_id = packet.get_uint32()

                self.log_received_packet(packet_type, packet_id, packet)
                await self._process_packet(packet_type, packet_id, packet)

        except PacketDecodeError as exc:
            await self._cleanup(BadMessage(str(exc)))
        except EOFError:
            await self._cleanup(None)
        except (OSError, Error) as exc:
            await self._cleanup(exc)


class ClientSubsystemHandler(SubsytemHandler):
    """An subsystem client handler.

        # Make a request
        async def something(self, do_this):
            return await self._make_request(PKT_TYPE, String(do_this))

        # Process an incoming response
        def _process_something(self, packet: SSHPacket) -> Any:
            data = packet.get_string()
            packet.check_end()
            return data
    """

    _extensions = []

    def __init__(self, loop, reader, writer):
        super().__init__(reader, writer)

        self._loop = loop
        self._version = None
        self._next_packet_id = 0
        self._requests = {}

    async def _cleanup(self, exc):
        """Clean up this client session"""
        req_exc = exc or ConnectionLost('Connection closed')

        for waiter in self._requests.values():
            if not waiter.cancelled():
                waiter.set_exception(req_exc)

        self._requests = {}

        self.logger.info('Client exited%s', ': ' + str(exc) if exc else '')
        await super()._cleanup(exc)

    async def _process_packet(self, packet_type, packet_id, packet):
        """Process incoming responses."""
        try:
            waiter = self._requests.pop(packet_id)
        except KeyError:
            await self._cleanup(BadMessage('Invalid response id'))
        else:
            if not waiter.cancelled():  # pragma: no branch
                waiter.set_result((packet_type, packet))

    def _send_request(self, packet_type, args, waiter):
        """Send a request."""

        if not self._writer:
            raise NoConnection('Connection not open')

        packet_id = self._next_packet_id
        self._next_packet_id = (self._next_packetid + 1) & 0xffffffff

        self._requests[packet_id] = waiter

        if isinstance(packet_type, bytes):
            header = UInt32(packet_id) + String(packet_type)
            packet_type = FXP_EXTENDED
        else:
            header = UInt32(packet_id)

        self.send_packet(packet_type, packet_id, header, *args)

    async def _make_request(self, packet_type, *args):
        """Make a request and wait for a response."""

        waiter = self._loop.create_future()
        self._send_request(packet_type, args, waiter)
        resptype, resp = await waiter

        return_type = self._return_types.get(packet_type)

        if resptype not in (FXP_STATUS, return_type):
            raise BadMessage('Unexpected response type: %s' % resptype)

        result = self._packet_handlers[resptype](self, resp)

        if result is not None or return_type is None:
            return result
        else:
            raise BadMessage('Unexpected FX_OK response')

    _packet_handlers = {
        # PKT_TYPE: _process_something
    }

    async def start(self):
        """Start an client."""
        extensions = (String(name) + String(data) for name, data in self._extensions)
        self.send_packet(FXP_INIT, None, UInt32(_VERSION), *extensions)

        try:
            resp = await self.receive_packet()

            resptype = resp.get_byte()

            self.log_received_packet(resptype, None, resp)

            if resptype != FXP_VERSION:
                raise BadMessage('Expected version message')

            version = resp.get_uint32()

            if version != _VERSION:
                raise BadMessage('Unsupported version: %d' % version)

            self._version = version

            extensions = []

            while resp:
                name = resp.get_string()
                data = resp.get_string()
                extensions.append((name, data))
        except PacketDecodeError as exc:
            raise BadMessage(str(exc)) from None
        except (asyncio.IncompleteReadError, Error) as exc:
            raise Failure(str(exc)) from None

        self.logger.debug1('Received version=%d%s', version,
                           ', extensions:' if extensions else '')

        for name, data in extensions:
            self.logger.debug1('  %s: %s', name, data)

            if name == b'posix-rename@openssh.com' and data == b'1':
                self._supports_posix_rename = True
            elif name == b'statvfs@openssh.com' and data == b'2':
                self._supports_statvfs = True
            elif name == b'fstatvfs@openssh.com' and data == b'2':
                self._supports_fstatvfs = True
            elif name == b'hardlink@openssh.com' and data == b'1':
                self._supports_hardlink = True
            elif name == b'fsync@openssh.com' and data == b'1':
                self._supports_fsync = True

        if version == 3:
            # Check if the server has a buggy SYMLINK implementation

            server_version = self._reader.get_extra_info('server_version', '')
            if any(name in server_version
                   for name in self._nonstandard_symlink_impls):
                self.logger.debug1('Adjusting for non-standard symlink '
                                   'implementation')
                self._nonstandard_symlink = True

    def exit(self):
        """Handle a request to close the session."""
        if self._writer:
            self._writer.write_eof()

    async def wait_closed(self):
        """Wait for this session to close."""
        if self._writer:
            await self._writer.channel.wait_closed()


class SubsystemClient(ContainerAware):
    """Client.
    
        @async_context_manager
        async def something(self, data):
            pass
    """

    def __init__(self, ioc, handler):
        ContainerAware.__init__(ioc)
        self._handler = handler

    async def __aenter__(self):
        """Allow client to be used as an async context manager"""
        return self

    async def __aexit__(self, *exc_info):
        """Wait for client close when used as an async context manager"""

        self.exit()
        await self.wait_closed()

    @property
    def logger(self):
        """A logger associated with this client"""
        return self._handler.logger

    def exit(self):
        """Exit the client session."""
        self._handler.exit()

    async def wait_closed(self):
        """Wait for this client session to close."""
        await self._handler.wait_closed()


class ServerSubsystemHandler(SubsytemHandler):
    """A server session handler.

        # Process an incoming SFTP open request
        async def _process_something(self, packet: SSHPacket):
            data = packet.get_string()
            packet.check_end()

            result = self._server.something(data)

            if inspect.isawaitable(result):
                result = await result

            handle = self._get_next_handle()
            return handle
    """

    _extensions = []

    def __init__(self, server, reader, writer):
        super().__init__(reader, writer)

        self._server = server
        self._version = None
        self._next_handle = 0

    async def _cleanup(self, exc):
        """Clean up this SFTP server session"""

        if self._server:  # pragma: no branch
            self._server.exit()
            self._server = None

        await super()._cleanup(exc)

    async def _process_packet(self, packet_type, pktid, packet):
        """Process incoming requests"""

        try:
            if packet_type == FXP_EXTENDED:
                packet_type = packet.get_string()

            handler = self._packet_handlers.get(packet_type)
            if not handler:
                raise OpUnsupported('Unsupported request type: %s' % packet_type)

            return_type = self._return_types.get(packet_type, FXP_STATUS)
            result = await handler(self, packet)

            if return_type == FXP_STATUS:
                self.logger.debug1('Sending OK')
                result = UInt32(FX_OK) + String('') + String('')

            elif return_type == FXP_HANDLE:
                self.logger.debug1('Sending handle %s', to_hex(result))
                result = String(result)

            elif return_type == FXP_DATA:
                result = String(result)

            elif return_type == FXP_NAME:
                for name in result:
                    self.logger.debug1('  %s', name)
                result = (UInt32(len(result)) +
                          b''.join(name.encode() for name in result))
            else:
                if isinstance(result, os.stat_result):
                    pass
                elif isinstance(result, os.statvfs_result):
                    pass

                if isinstance(result, type(None)):
                    self.logger.debug1('Sending %s', result)
                elif isinstance(result, type(None)):  # pragma: no branch
                    self.logger.debug1('Sending %s', result)
                result = result.encode()

        except PacketDecodeError as exc:
            return_type = FXP_STATUS
            self.lgger.debug1('Sending bad message error: %s', str(exc))
            result = (UInt32(FX_BAD_MESSAGE) + String(str(exc)) +
                      String(DEFAULT_LANG))

        except Error as exc:
            return_type = FXP_STATUS
            if exc.code == FX_EOF:
                self.logger.debug1('Sending EOF')
            else:
                self.logger.debug1('Sending error: %s', str(exc.reason))
            result = UInt32(exc.code) + String(exc.reason) + String(exc.lang)

        except NotImplementedError as exc:
            return_type = FXP_STATUS
            name = handler.__name__[9:]
            self.logger.debug1('Sending operation not supported: %s', name)
            result = (UInt32(FX_OP_UNSUPPORTED) +
                      String('Operation not supported: %s' % name) +
                      String(DEFAULT_LANG))

        except OSError as exc:
            return_type = FXP_STATUS
            reason = exc.strerror or str(exc)

            if exc.errno in (errno.ENOENT, errno.ENOTDIR):
                self.logger.debug1('Sending no such file error: %s', reason)
                code = FX_NO_SUCH_FILE
            elif exc.errno == errno.EACCES:
                self.logger.debug1('Sending permission denied: %s', reason)
                code = FX_PERMISSION_DENIED
            else:
                self.logger.debug1('Sending failure: %s', reason)
                code = FX_FAILURE
            result = UInt32(code) + String(reason) + String(DEFAULT_LANG)
        except Exception as exc:  # pragma: no cover
            return_type = FXP_STATUS
            reason = 'Uncaught exception: %s' % str(exc)
            self.logger.debug1('Sending failure: %s', reason)
            result = UInt32(FX_FAILURE) + String(reason) + String(DEFAULT_LANG)

        self.send_packet(return_type, pktid, UInt32(pktid), result)

    _packet_handlers = {
        # FXP_PACKET: _process_something,
    }

    async def run(self):
        """Run a server."""
        try:
            packet = await self.receive_packet()
            packet_type = packet.get_byte()

            self.log_received_packet(packet_type, None, packet)

            version = packet.get_uint32()

            extensions = []

            while packet:
                name = packet.get_string()
                data = packet.get_string()
                extensions.append((name, data))
        except PacketDecodeError as exc:
            await self._cleanup(BadMessage(str(exc)))
            return
        except Error as exc:
            await self._cleanup(exc)
            return

        if packet_type != FXP_INIT:
            await self._cleanup(BadMessage('Expected init message'))
            return

        self.logger.debug1('Received init, version=%d%s', version,
                           ', extensions:' if extensions else '')

        for name, data in extensions:
            self.logger.debug1('  %s: %s', name, data)

        reply_version = min(version, _VERSION)

        self.logger.debug1('Sending version=%d%s', reply_version,
                           ', extensions:' if self._extensions else '')

        for name, data in self._extensions:
            self.logger.debug1('  %s: %s', name, data)

        extensions = (String(name) + String(data) for name, data in self._extensions)

        try:
            self.send_packet(FXP_VERSION, None, UInt32(reply_version), *extensions)
        except Error as exc:
            await self._cleanup(exc)
            return

        if reply_version == 3:
            # Check if the server has a buggy SYMLINK implementation

            client_version = self._reader.get_extra_info('client_version', '')
            if any(name in client_version
                   for name in self._nonstandard_symlink_impls):
                self.logger.debug1('Adjusting for non-standard symlink '
                                   'implementation')
                self._nonstandard_symlink = True

        await self.receive_packets()


class SubsystemServer(ContainerAware):
    """Subsystem server.

        # A server side operation.
        def something(self, data):
            pass
    """

    def __init__(self, ioc, chan):
        ContainerAware.__init__(self, ioc)
        self._chan = chan

    @property
    def channel(self):
        """The channel associated with this server session."""
        return self._chan

    @property
    def connection(self):
        """The channel associated with this server session."""
        return self._chan.get_connection()

    @property
    def env(self):
        """The environment associated with this server session."""
        return self._chan.get_environment()

    @property
    def logger(self):
        """A logger associated with this SFTP server"""
        return self._chan.logger


async def start_client(conn: SSHConnection, loop, reader, writer):
    """Start a client"""
    handler = ClientSubsystemHandler(loop, reader, writer)
    await handler.start()
    conn.create_task(handler.receive_packets(), handler.logger)
    return SubsystemClient(handler)

def run_server(server: SubsystemServer, reader, writer):
    """Return a handler for a server session"""
    handler = ServerSubsystemHandler(server, reader, writer)
    return handler.run()
