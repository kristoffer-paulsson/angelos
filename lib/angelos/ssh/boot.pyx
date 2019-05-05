# cython: language_level=3
"""SSH Bootstrap code for the Angelos server."""
import logging
import os

import asyncssh

from ..utils import Util
from ..const import Const
from .ssh import SSHServer
from ..server.cmd import Terminal
from ..server.commands import (
    QuitCommand, SetupCommand, StartupCommand, EnvCommand)
from ..ioc import ContainerAware


class BootServer(ContainerAware, SSHServer):
    """SSH Server for the boot sequence."""

    def __init__(self, ioc):
        """Initialize BootServer."""
        ContainerAware.__init__(self, ioc)
        SSHServer.__init__(self)
        self._applog = self.ioc.log.app

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
        return asyncssh.SSHServerProcess(self.terminal, None, False)

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
                commands=[SetupCommand, QuitCommand, EnvCommand],
                ioc=self.ioc, process=process).run())
