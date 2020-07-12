# cython: language_level=3
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
"""SSH Bootstrap code for the Angelos server."""
import crypt
import logging
import os
import uuid

import asyncssh
from angelos.cmd import Terminal
from libangelos.ioc import ContainerAware

from angelos.commands import EnvCommand, QuitCommand, SetupCommand, StartupCommand, ProcessCommand
from angelos.impexp import ImportCommand, ExportCommand, PortfolioCommand
from libangelos.const import Const
from libangelos.ssh.ssh import SSHServer, SessionHandle
from libangelos.utils import Util


class ConsoleServerProcess(asyncssh.SSHServerProcess):
    """Boot server process that interacts with session manager."""

    def __init__(self, process_factory, sess_mgr, name):
        super().__init__(process_factory, None, False)
        self._session_manager = sess_mgr
        self._uuid = uuid.uuid4()

        self._session_manager.add_session(
            name, SessionHandle(self._uuid, self)
        )

    def close(self, sessmgr=False):
        result = super().close()
        if not sessmgr:
            self._session_manager.close_session(self._uuid)
        return result


class BootServerProcess(ConsoleServerProcess):
    def __init__(self, process_factory, sess_mgr):
        ConsoleServerProcess.__init__(self, process_factory, sess_mgr, "boot")


class AdminServerProcess(ConsoleServerProcess):
    def __init__(self, process_factory, sess_mgr):
        ConsoleServerProcess.__init__(self, process_factory, sess_mgr, "admin")


class ConsoleServer(ContainerAware, asyncssh.SSHServer):
    """SSH server container aware baseclass."""

    def __init__(self, ioc):
        """Initialize AdminServer."""
        self._conn = None
        self._client_keys = None
        ContainerAware.__init__(self, ioc)

        self._applog = self.ioc.log.app

    def connection_made(self, conn):
        """Handle the incoming connection."""
        self._conn = conn
        conn.send_auth_banner("Connection made\n")

    def begin_auth(self, username):
        """Authentication is required."""
        try:
            self._client_keys = self.ioc.keys.list()
        except IOError as e:
            self._conn.close()

        return True

    def public_key_auth_supported(self):
        """Turn on support for public key authentication."""
        return True

    def validate_public_key(self, username, key):
        """Validate public key."""
        return key in self._client_keys


class BootServer(ConsoleServer):
    """SSH Server for the boot sequence."""

    def __init__(self, ioc):
        """Initialize BootServer."""
        ConsoleServer.__init__(self, ioc)

        vault_file = Util.path(self.ioc.env["dir"].root, Const.CNL_VAULT)
        if os.path.isfile(vault_file):
            self._applog.info("Vault archive found. Initialize startup mode.")
        else:
            self._applog.info(
                "Vault archive NOT found. Initialize setup mode."
            )

    def session_requested(self):
        """Start terminal session. Denying SFTP and SCP."""
        logging.debug("Session requested")
        return BootServerProcess(self.terminal, self.ioc.session)

    async def terminal(self, process):
        """
        Client handler, returns Terminal instance.

        The terminal will be equipped for setup or startup.
        """
        vault_file = Util.path(self.ioc.env["dir"].root, Const.CNL_VAULT)

        if os.path.isfile(vault_file):
            return await Terminal(
                commands=[StartupCommand, QuitCommand],
                ioc=self.ioc,
                process=process,
            ).run()
        else:
            return await Terminal(
                commands=[SetupCommand, QuitCommand],
                ioc=self.ioc,
                process=process,
            ).run()


class AdminServer(ConsoleServer):
    """SSH Server for the admin console."""

    cmds = [
        EnvCommand,
        QuitCommand,
        ImportCommand,
        ExportCommand,
        ProcessCommand,
        PortfolioCommand,
    ]

    def session_requested(self):
        """Start terminal session. Denying SFTP and SCP."""
        logging.debug("Session requested")
        return AdminServerProcess(self.terminal, self.ioc.session)

    async def terminal(self, process):
        """
        Client handler, returns Terminal instance.

        The terminal will be equipped for setup or startup.
        """
        return await Terminal(
            commands=AdminServer.cmds, ioc=self.ioc, process=process
        ).run()
