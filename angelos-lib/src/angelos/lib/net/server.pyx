# cython: language_level=3, linetrace=True
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
import inspect
import os
import uuid
from typing import List

import asyncssh
from asyncssh import SSHServer, SSHServerSession, EXTENDED_DATA_STDERR, BreakReceived, SignalReceived, create_server
from asyncssh.misc import SoftEOFReceived, TerminalSizeChanged
from asyncssh.stream import SSHStreamSession, SSHReader, SSHWriter
from angelos.lib.error import PortfolioExistsNot
from angelos.lib.ioc import ContainerAware, Container
from angelos.lib.policy.portfolio import PGroup
from angelos.lib.ssh.nacl import NaClKey

from angelos.lib.net.subsystem import ServerSubsystemHandler, SubsystemServer


class ServerTerminal:
    pass


MODE_STRICT = 1  # Verified and trusted by the server
MODE_KNOWN = 2  # Trusted by the server and verified by other user
MODE_INVITE = 3  # Trusted and verified by users or server
MODE_OPEN = 4  # Verified by user or server




class SessionOptions:
    """Session access options."""

    ROLE_NONE = 0
    ROLE_ADMIN = 1
    ROLE_HOST = 2
    ROLE_CLIENT = 3
    ROLE_NODE = 5

    def __init__(self):
        self.__username = ""
        self.__issuer = None
        self.__role = self.ROLE_NONE
        self.__terminal_access = False
        self.__systems = dict()


class ServerSession(ContainerAware, SSHStreamSession, SSHServerSession):
    """Server session base class."""

    def __init__(self, ioc, subsystems: List[ServerSubsystemHandler] = None, terminal: ServerTerminal = None):
        ContainerAware.__init__(self, ioc)
        SSHStreamSession.__init__(self)

        self._terminal = terminal
        self._subsystems = dict()

        for system in subsystems if subsystems else list():
            self._subsystems[system.SYSTEM[0]] = system

    def pty_requested(self, term_type, term_size, term_modes) -> bool:
        """Find out if server allows a terminal."""
        return False

    def subsystem_requested(self, subsystem: str) -> bool:
        """Find out if certain subsystem is available."""
        if subsystem in self._subsystems.keys():
            return True

    def session_started(self):
        """Start a session for this newly opened server channel"""
        handler = None
        subsystem = self._chan.get_subsystem()

        if subsystem in self._subsystems.keys():
            stdin = SSHReader(self, self._chan)
            stdout = SSHWriter(self, self._chan)
            stderr = SSHWriter(self, self._chan, EXTENDED_DATA_STDERR)

            handler = self._subsystems[subsystem](SubsystemServer(self.ioc, self._chan), stdin, stdout)

        if inspect.isawaitable(handler):
            self._conn.create_task(handler, stdin.logger)

    def break_received(self, msec) -> bool:
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

    def terminal_size_changed(self, width: int, height: int, pixwidth: int, pixheight: int):
        """Handle an incoming terminal size change on the channel"""
        self._recv_buf[None].append(TerminalSizeChanged(width, height, pixwidth, pixheight))
        self._unblock_read(None)


class Server(ContainerAware, SSHServer):
    """Server base class."""

    def __init__(
            self, ioc: Container, mode: int = MODE_STRICT,
            subsystems: List[ServerSubsystemHandler] = None, terminal: ServerTerminal = None
    ):
        ContainerAware.__init__(self, ioc)
        self._portfolio = None
        self._conn = None
        self._who = self.WHO_NONE
        self._client_keys = None

        self._mode = mode
        self._active = dict()

        self._terminal = terminal
        self._subsystems = dict()


        for system in subsystems if subsystems else list():
            self._subsystems[system.SYSTEM[0]] = system

    @classmethod
    async def start(
            cls, ioc: Container, mode: int = MODE_STRICT, port: int = 8022,
            host_keys=["ssh_host_key"], auth_client_keys="authorized_keys"
    ) -> "Server":
        """Creates an asynchronous SSH server."""
        return await create_server(
            lambda: cls(ioc, mode), "", port,
            server_host_keys=host_keys,
            authorized_client_keys=auth_client_keys,
        )

    def connection_requested(self, dest_host, dest_port, orig_host, orig_port):
        """Run a new TCP session that handles an SSH client connection"""
        return ServerSession(self.ioc)

    def connection_made(self, conn):
        """Remember latest connection."""
        self._client_keys = None
        self._who = self.WHO_NONE
        self._conn = conn

    def connection_lost(self, exc):
        """Clean up among connections if one is lost"""
        self.clean_up()

    def _load_admin_keys(self, username: str):
        try:
            key_file = os.path.join(os.path.expanduser("~"), ".ssh", "authorized_keys", username + ".pub")
            self._client_keys = asyncssh.read_public_key_list(key_file)
        except IOError:
            self._conn.close()

    def _load_portfolio_keys(self, issuer: uuid.UUID):
        try:
            portfolio = self.ioc.facade.storage.vault.load_portfolio(
                 issuer, PGroup.CLIENT_AUTH
            )
            self._client_keys = [NaClKey.factory(key) for key in portfolio.keys]
        except PortfolioExistsNot:
            self._conn.close()

    def begin_auth(self, username: str) -> bool:
        """Prepare for authentication of user."""

        # First check that a user don't already have a connection
        if username in self._active.keys():
            self._conn.close()
        else:
            self._active[username] = self._conn

        # Check whether it is a user or admin
        try:
            issuer = uuid.UUID(username)
        except ValueError:
            self._who = self.WHO_ADMIN
            self._load_admin_keys(username)
        else:
            # A client, node or host
            if issuer == self.ioc.facade.data.portfolio.entity.id:
                self._who = self.WHO_NODE
                self._client_keys = [NaClKey.factory(key) for key in self.ioc.facade.data.portfolio.keys]
            else:
                self._who = self.WHO_CLIENT
                self._load_portfolio_keys(issuer)

        self._conn = None
        return True

    def validate_public_key(self, username, key):
        """Validate public key."""
        return key in self._client_keys

    def kick_out(self, username: str):
        """Kick out user."""
        if username in self._active.keys():
            self._active[username].abort()
            del self._active[username]

    def clean_up(self):
        """Clean up dead connections."""
        purge = set()
        for username in self._active.keys():
            if len(self._active[username]._channels) == 0:
                purge.add(username)

        for username in purge:
            del self._active[username]
