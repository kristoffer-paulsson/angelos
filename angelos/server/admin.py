"""Module docstring."""
import asyncio
import asyncssh
import sys
import logging
from ..utils import Util
from ..const import Const
from ..error import CmdShellEmpty, CmdShellInvalidCommand, CmdShellExit
from ..worker import Worker
from ..events import Message
from .cmd import Shell
from .common import SERVER_RSA_PRIVATE, CLIENT_RSA_PUBLIC
from .commands import ServerCommand


class AdminConsole(Shell):
    """Docstring"""
    def __init__(self, ioc, stdin=sys.stdin, stdout=sys.stdout):
        Shell.__init__(self, [ServerCommand], ioc, stdin, stdout)


class AdminServer(Worker):
    """Docstring"""
    def _initialize(self):
        logging.info('#'*10 + 'Entering ' + self.__class__.__name__ + '#'*10)
        self.task(self.__server)

    def _finalize(self):
        logging.info('#'*10 + 'Leaving ' + self.__class__.__name__ + '#'*10)

    def _panic(self):
        logging.info('#'*10 + 'Panic ' + self.__class__.__name__ + '#'*10)
        self.ioc.message.send(Message(
            Const.W_ADMIN_NAME, Const.W_SUPERV_NAME, 1, {}))

    @asyncio.coroutine
    async def __server(self):  # noqa E999
        logging.info('#'*10 + 'Entering __server' + '#'*10)
        try:
            await asyncssh.listen('localhost', 22, server_host_keys=[
                asyncssh.import_private_key(SERVER_RSA_PRIVATE)],
                authorized_client_keys=asyncssh.import_authorized_keys(
                CLIENT_RSA_PUBLIC), process_factory=self.__terminal)
        except PermissionError as exc:
            logging.error(
                Util.format_error(exc, 'Admin console server failed to start'))
            self.ioc.message.send(Message(
                Const.W_ADMIN_NAME, Const.W_SUPERV_NAME, 1, {}))
        logging.info('#'*10 + 'Leaving __server' + '#'*10)

    async def __terminal(self, process):
        logging.info('#'*10 + 'Entering __terminal' + '#'*10)
        config = self.ioc.environment['terminal']
        shell = AdminConsole(self.ioc, process.stdin, process.stdout)

        process.stdout.write(
            '\033[41m\033[H\033[J' + config['message'] +
            Shell.EOL + '='*79 + Shell.EOL)

        while not process.stdin.at_eof() and not self._halt.is_set():
            try:
                process.stdout.write(config['prompt'])
                line = await process.stdin.readline()
                shell.execute(line.strip())
            except CmdShellInvalidCommand as exc:
                process.stdout.write(str(exc) + Shell.EOL +
                                     'Try \'help\' or \'<command> -h\'' +
                                     Shell.EOL*2)
            except (CmdShellEmpty, asyncssh.TerminalSizeChanged):
                continue
            except CmdShellExit:
                break

        process.stdout.write('\033[40m\033[H\033[J')
        process.close()
        process.exit(0)
        logging.info('#'*10 + 'Leaving __terminal' + '#'*10)
