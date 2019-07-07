# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
import logging
import uuid
import asyncio

from ..policy import StatementPolicy, PGroup
from ..operation.replication import ReplicatorServerHandler, ReplicatorServer
from .ssh import SSHServer, SSHClient
from .nacl import NaClKey

from asyncssh import (
    SSHStreamSession, SSHServerSession, SSHReader, SSHWriter, BreakReceived,
    SignalReceived)


class ClientsClient(SSHClient):
    pass


class ClientsServer(SSHServer):
    """SSH Server for the clients."""

    @asyncio.coroutine
    async def begin_auth(self, username):
        logging.info('Begin authentication for: %s' % username)

        try:
            issuer = uuid.UUID(username)
            portfolio = await self.ioc.facade.load_portfolio(
                issuer, PGroup.CLIENT_AUTH)

            if StatementPolicy.validate_trusted(
                    self.ioc.facade.portfolio, portfolio):
                self._client_keys = [
                    NaClKey.factory(key) for key in portfolio.keys]
        except OSError as e:
            logging.error('User not found: %s' % username)
            self._client_keys = []

        return True

    def validate_public_key(self, username, key):
        logging.info('Authentication for a user')
        logging.debug('%s' % username)
        return key in self._client_keys

    def session_requested(self):
        logging.debug('Session requested')
        return ServerReplicatorSession(True)


class ServerReplicatorSession(SSHStreamSession, SSHServerSession):
    """SSH server stream session handler"""

    def __init__(self, allow_replicator):
        super().__init__()

        self._allow_replicator = allow_replicator

    def pty_requested(self, term_type, term_size, term_modes):
        """Deny pseudo-tty."""
        return False

    def subsystem_requested(self, subsystem):
        """Return whether starting a subsystem can be requested"""
        if subsystem == 'replicator':
            return bool(self._allow_replicator)

        return False

    def session_started(self):
        """Start a session for this newly opened server channel"""
        stdin = SSHReader(self, self._chan)
        stdout = SSHWriter(self, self._chan)

        if self._chan.get_subsystem() == 'replicator':
            self._chan.set_encoding(None)
            self._encoding = None

            handler = self.__run_replicator_server(
                ReplicatorServer(self._conn), stdin, stdout)
        else:
            handler = None

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

    @asyncio.coroutine
    async def __run_replicator_server(replicator_server, reader, writer):
        """Return a handler for an SFTP server session"""
        handler = ReplicatorServerHandler(replicator_server, reader, writer)
        handler.logger.info('Starting Replicator server')
        return (await handler.run())
