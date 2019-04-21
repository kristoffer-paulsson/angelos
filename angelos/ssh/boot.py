"""SSH Bootstrap code for the Angelos server."""
import logging
import asyncio

import asyncssh

from .ssh import SSHServer
from ..server.cmd import Shell
from ..ioc import ContainerAware
from ..error import CmdShellEmpty, CmdShellInvalidCommand, CmdShellExit


class BootServer(ContainerAware, SSHServer):
    """SSH Server for the boot sequence."""

    def __init__(self, ioc):
        """Initialize BootServer."""
        ContainerAware.__init__(self, ioc)
        SSHServer.__init__(self)

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
        """Client handler, returns Terminal instance."""
        return (await Terminal(
            commands=[], ioc=self.ioc, process=process).run())


class Terminal(Shell):
    """Asynchronoius instance of Shell."""

    __lock = asyncio.Lock()

    def __init__(self, commands, ioc, process):
        """Initialize Terminal from SSHServerProcess."""
        Shell.__init__(self, commands=commands, ioc=ioc,
                       stdin=process.stdin, stdout=process.stdout)
        self._process = process
        self._size = process.get_terminal_size()
        self._config = self.ioc.environment['terminal']

    async def run(self):
        """Looping the Shell interpreter."""
        if self.__lock.locked():
            self._process.close()
            return
        async with self.__lock:
            try:
                self._process.stdout.write(
                    '\033[41m\033[H\033[J' + self._config['message'] +
                    Shell.EOL + '='*79 + Shell.EOL)

                self._process.stdout.write(self._config['prompt'])
                while not self._process.stdin.at_eof():
                    try:
                        line = await self._process.stdin.readline()
                        self.execute(line.strip())
                    except CmdShellInvalidCommand as exc:
                        self._process.stdout.write(
                            str(exc) + Shell.EOL +
                            'Try \'help\' or \'<command> -h\'' + Shell.EOL*2)
                    except CmdShellEmpty:
                        pass
                    except asyncssh.TerminalSizeChanged:
                        self._size = self._process.get_terminal_size()
                        continue
                    except CmdShellExit:
                        break
                    self._process.stdout.write(self._config['prompt'])

                self._process.stdout.write('\033[40m\033[H\033[J')
                self._process.close()
            except asyncssh.BreakReceived:
                pass
