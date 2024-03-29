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
"""Module docstring."""
import asyncio
import logging
import uuid

from angelos.common.utils import Util
from angelos.facade.operation import ValidateTrust
from angelos.lib.replication.endpoint import ReplicatorServer, ReplicatorClient
from angelos.lib.replication.handler import ReplicatorServerHandler, ReplicatorClientHandler
from angelos.lib.replication.preset import Preset
from angelos.lib.ssh.nacl import NaClKey
from angelos.lib.ssh.ssh import SSHServer, SSHClient
from angelos.portfolio.statement.validate import ValidateTrustedStatement
from angelos.portfolio.utils import Groups
from asyncssh import SSHServerSession, SSHReader, SSHWriter, BreakReceived, SignalReceived, SSHClientSession
from asyncssh.stream import SSHStreamSession


class ClientsClient(SSHClient):
    async def mail(self):
        """Start mail replication operation."""
        writer, reader, _ = await self._connection.open_session(
            subsystem="replicator", encoding=None
        )
        preset = self.ioc.facade.api.replication.create_preset(
            Preset.T_MAIL,
            Preset.CLIENT,
            self.ioc.facade.data.portfolio.entity.id,
        )
        repclient = ReplicatorClient(self.ioc, preset)
        session = ClientReplicatorSession()
        handler = session.start_replicator_client(
            repclient, reader, writer, "mail"
        )

        await handler
        # if asyncio.iscoroutine(handler):
        #    self._connection.create_task(handler, stderr.logger)


class ClientReplicatorSession(SSHStreamSession, SSHClientSession):
    """SSH server stream session handler."""

    @asyncio.coroutine
    async def start_replicator_client(
        self, replicator_client, reader, writer, preset="custom"
    ):
        """Return a handler for an SFTP server session"""
        replicator_client.channel = self._chan
        handler = ReplicatorClientHandler(replicator_client, reader, writer)
        handler.logger.info("Starting Replicator client")
        return await handler.start()


class ClientsServer(SSHServer):
    """SSH Server for the clients."""

    def __init__(self, ioc):
        SSHServer.__init__(self, ioc)
        self._portfolio = None

    @asyncio.coroutine
    async def begin_auth(self, username):
        logging.info("Begin authentication for: %s" % username)

        try:
            issuer = uuid.UUID(username)
            self._portfolio = await self.ioc.facade.storage.vault.load_portfolio(issuer, Groups.CLIENT_AUTH)

            if ValidateTrust().validate(self.ioc.facade.data.portfolio, self._portfolio):
                self._client_keys = [NaClKey.factory(key) for key in self._portfolio.keys]
            else:
                logging.warning("Unauthorized user: %s" % username)
                self._conn.close()
        except OSError as e:
            logging.error("User not found: %s" % username)
            self._client_keys = []

        return True

    def validate_public_key(self, username, key):
        logging.info("Authentication for a user")
        logging.debug("%s" % username)
        return key in self._client_keys

    def session_requested(self):
        logging.debug("Session requested")
        return ServerReplicatorSession(True, self.ioc, self._portfolio)


class ServerReplicatorSession(SSHStreamSession, SSHServerSession):
    """SSH server stream session handler"""

    def __init__(self, allow_replicator, ioc, portfolio):
        SSHStreamSession.__init__(self)
        SSHServerSession.__init__(self)

        self._allow_replicator = allow_replicator
        self._ioc = ioc
        self._portfolio = portfolio

    def pty_requested(self, term_type, term_size, term_modes):
        """Deny pseudo-tty."""
        return False

    def subsystem_requested(self, subsystem):
        """Return whether starting a subsystem can be requested"""
        if subsystem == "replicator":
            return bool(self._allow_replicator)

        return False

    def session_started(self):
        """Start a session for this newly opened server channel"""
        reader = SSHReader(self, self._chan)
        writer = SSHWriter(self, self._chan)

        if self._chan.get_subsystem() == "replicator":
            self._chan.set_encoding(None)
            self._encoding = None

            handler = self.__run_replicator_server(
                ReplicatorServer(self._ioc, self._conn, self._portfolio),
                reader,
                writer,
            )
        else:
            handler = None

        if asyncio.iscoroutine(handler):
            self._conn.create_task(handler, reader.logger)

    def break_received(self, msec):
        """Handle an incoming break on the channel"""
        self._recv_buf[None].append(BreakReceived(msec))
        self._unblock_read(None)
        return True

    def signal_received(self, signal):
        """Handle an incoming signal on the channel"""
        self._recv_buf[None].append(SignalReceived(signal))
        self._unblock_read(None)

    # @asyncio.coroutine
    async def __run_replicator_server(self, replicator_server, reader, writer):
        """Return a handler for an SFTP server session"""
        replicator_server.channel = self._chan
        handler = ReplicatorServerHandler(replicator_server, reader, writer)
        return await handler.run()
