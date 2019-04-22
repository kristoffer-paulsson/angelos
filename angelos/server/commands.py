"""Server commands."""
import os
import signal
import asyncio
import time

from ..utils import Util
from ..error import Error
from .cmd import Command, Option


class QuitCommand(Command):
    """Shutdown the angelos server."""

    short = """Shutdown the angelos server"""
    description = """Use this command to shutdown the angelos server from the terminal."""  # noqa E501

    def __init__(self):
        """Initialize the command. Takes a list of Command classes."""
        Command.__init__(self, 'quit')

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return [Option(
            'yes',
            short='y',
            type=Option.TYPE_BOOL,
            help='Confirm that you want to shutdown server')]

    def _command(self, opts):
        if opts['yes']:
            self._stdout.write(
                '\nStarting shutdown sequence for the Angelos server.\n\n')
            asyncio.ensure_future(self._quit())
            for t in ['3', '.', '.', '2', '.', '.', '1', '.', '.', '0']:
                self._stdout.write(t)
                time.sleep(.333)
            raise Util.exception(Error.CMD_SHELL_EXIT)
        else:
            self._stdout.write(
                '\nYou didn\'t confirm shutdown sequence. Use --yes/-y.\n\n')

    async def _quit(self):
        await asyncio.sleep(5)
        os.kill(os.getpid(), signal.SIGINT)


"""
class ServerCommand(Command):
    short = 'Operates the servers runstate.'
    description = With the server command you can operate the servers run
state. you can "start", "restart" and "shutdown" the softaware using the
options available. "shutdown" requires you to confirm with the "yes"
option."

    def __init__(self, message):
        Command.__init__(self, 'server')
        Util.is_type(message, Events)
        self.__events = message

    def _options(self):
        return[
            Option(
                'start', type=Option.TYPE_BOOL,
                help='Elevates the servers run state into operational mode'),
            Option('restart', type=Option.TYPE_BOOL,
                   help='Restarts the server'),
            Option('shutdown', type=Option.TYPE_BOOL,
                   help='Shuts down the server'),
            Option('yes', short='y', type=Option.TYPE_BOOL,
                   help='Use to confirm "shutdown"'),
        ]

    def _command(self, opts):
        if opts['start']:
            self._stdout.write(
                '"start" operation not implemented.' + Shell.EOL)

        elif opts['restart']:
            self._stdout.write(
                '"restart" operation not implemented.' + Shell.EOL)

        elif opts['shutdown']:
            if opts['yes']:
                self._stdout.write('Commencing operation "shutdown".' +
                                   Shell.EOL + 'Good bye!' + Shell.EOL)
                self.__events.send(Message(
                    Const.W_ADMIN_NAME, Const.W_SUPERV_NAME, 1, {}))
                for r in range(5):
                    self._stdout.write('.')
                    time.sleep(1)
                raise CmdShellExit()
            else:
                self._stdout.write(
                    'operation "shutdown" not confirmed.' + Shell.EOL)

        else:
            self._stdout.write(
                'No operation given. Type <server> -h for help.' + Shell.EOL)

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs['ioc'], Container)
        return ServerCommand(kwargs['ioc'].message)
"""
