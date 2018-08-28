from ..utils import Util
from ..error import CmdShellExit
from ..ioc import Container
from .cmd import Command, Option, Shell
from ..events import Events
from .main import ServerEvent


class ServerCommand(Command):
    short = 'Operates the servers runstate.'
    description = """With the server command you can operate the servers run
state. you can "start", "restart" and "shutdown" the softaware using the
options available. "shutdown" requires you to confirm with the "yes"
option."""

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
                self.__events.send(
                    ServerEvent('AdminServer', ServerEvent.MESSAGE_QUIT))
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
