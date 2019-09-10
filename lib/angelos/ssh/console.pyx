# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


SSH Bootstrap code for the Angelos server."""
import os
import uuid
import logging

import asyncssh

from ..utils import Util
from ..const import Const
from .ssh import SSHServer, SessionHandle
from ..server.cmd import Terminal
from ..server.commands import (
    EnvCommand, QuitCommand, SetupCommand, StartupCommand, ProcessCommand)
from ..server.impexp import ImportCommand, ExportCommand, PortfolioCommand
from ..dummy.command import DummyCommand


class ConsoleServerProcess(asyncssh.SSHServerProcess):
    """Boot server process that interacts with session manager."""

    def __init__(self, process_factory, sess_mgr, name):
        super().__init__(process_factory, None, False)
        self._session_manager = sess_mgr
        self._uuid = uuid.uuid4()

        self._session_manager.add_session(
            name, SessionHandle(self._uuid, self))

    def close(self, sessmgr=False):
        result = super().close()
        if not sessmgr:
            self._session_manager.close_session(self._uuid)
        return result


class BootServerProcess(ConsoleServerProcess):
    def __init__(self, process_factory, sess_mgr):
        ConsoleServerProcess.__init__(self, process_factory, sess_mgr, 'boot')


class AdminServerProcess(ConsoleServerProcess):
    def __init__(self, process_factory, sess_mgr):
        ConsoleServerProcess.__init__(self, process_factory, sess_mgr, 'admin')


class BootServer(SSHServer):
    """SSH Server for the boot sequence."""

    def __init__(self, ioc):
        """Initialize BootServer."""
        SSHServer.__init__(self, ioc)

        vault_file = Util.path(self.ioc.env['dir'].root, Const.CNL_VAULT)
        if os.path.isfile(vault_file):
            self._applog.info(
                'Vault archive found. Initialize startup mode.')
        else:
            self._applog.info(
                'Vault archive NOT found. Initialize setup mode.')

    def begin_auth(self, username):
        """Auth not required."""
        logging.info('Begin authentication for: %s' % username)
        return False

    def password_auth_supported(self):
        """Password validation supported."""
        return True

    def validate_password(self, username, password):
        """Any password OK."""
        return True

    def session_requested(self):
        """Start terminal session. Denying SFTP and SCP."""
        logging.debug('Session requested')
        return BootServerProcess(self.terminal, self.ioc.session)

    async def terminal(self, process):
        """
        Client handler, returns Terminal instance.

        The terminal will be equipped for setup or startup.
        """
        vault_file = Util.path(self.ioc.env['dir'].root, Const.CNL_VAULT)

        if os.path.isfile(vault_file):
            return (await Terminal(
                commands=[StartupCommand, QuitCommand],
                ioc=self.ioc, process=process).run())
        else:
            return (await Terminal(
                commands=[SetupCommand, QuitCommand],
                ioc=self.ioc, process=process).run())


class AdminServer(SSHServer):
    """SSH Server for the admin console."""

    cmds = [
        EnvCommand, QuitCommand, ImportCommand,
        ExportCommand, ProcessCommand, PortfolioCommand, DummyCommand]

    def begin_auth(self, username):
        """Auth not required."""
        logging.info('Begin authentication for: %s' % username)
        return False

    def password_auth_supported(self):
        """Password validation supported."""
        return True

    def validate_password(self, username, password):
        """Any password OK."""
        return True

    def session_requested(self):
        """Start terminal session. Denying SFTP and SCP."""
        logging.debug('Session requested')
        return AdminServerProcess(self.terminal, self.ioc.session)

    async def terminal(self, process):
        """
        Client handler, returns Terminal instance.

        The terminal will be equipped for setup or startup.
        """
        return (await Terminal(
            commands=AdminServer.cmds,
            ioc=self.ioc, process=process).run())
