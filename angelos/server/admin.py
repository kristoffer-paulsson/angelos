"""Docstring"""
import asyncio
import asyncssh
import sys
from ..error import CmdShellEmpty, CmdShellExit
from ..worker import Worker
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
        self._loop.create_task(self.__server())

    @asyncio.coroutine
    async def __server(self):  # noqa E999
        await asyncssh.listen(
            'localhost',
            22,
            server_host_keys=[asyncssh.import_private_key(SERVER_RSA_PRIVATE)],
            authorized_client_keys=asyncssh.import_authorized_keys(
                CLIENT_RSA_PUBLIC),
            process_factory=self.__terminal)

    async def __terminal(self, process):
        config = self.ioc.environment['terminal']
        shell = AdminConsole(self.ioc, process.stdin, process.stdout)

        process.stdout.write(
            '\033[41m\033[H\033[J' + config['message'] +
            Shell.EOL + '='*79 + Shell.EOL)

        while not process.stdin.at_eof() and not self._halt.is_set():
            try:
                process.stdout.write(config['prompt'])
                line = await process.stdin.readline()
                await shell.execute(line.strip())
            except CmdShellEmpty:
                continue
            except CmdShellExit:
                for r in range(5):
                    process.stdout.write('.')
                    await asyncio.sleep(1)
                break
            except asyncssh.TerminalSizeChanged:
                pass
            except Exception as ex:
                process.stdout.write(
                    str(ex) + Shell.EOL + 'Try \'help\' or \'<command> -h\'' +
                    Shell.EOL*2)
                continue
        process.stdout.write('\033[40m\033[H\033[J')
        process.close()
        process.exit(0)
