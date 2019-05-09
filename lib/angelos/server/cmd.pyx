# cython: language_level=3
"""Module docstring."""
import re
import asyncio
import logging

import asyncssh

from ..utils import Util, FactoryInterface
from ..error import CmdShellEmpty, CmdShellInvalidCommand, CmdShellExit, Error
from ..ioc import ContainerAware


class ConsoleIO:
    """IO class for the commands to gather input."""

    def __init__(self, process):
        """Configure the stdin and stdout stream."""
        self._process = process
        self._stdin = process.stdin
        self._stdout = process.stdout
        self._size = process.get_terminal_size()

    def upd_size(self):
        """Update terminal size at event."""
        self._size = self._process.get_terminal_size()

    def __lshift__(self, other):  # Print
        """Print to stdout C++ - style."""
        Util.is_type(other, str)
        self._stdout.write(other)

    async def prompt(self, msg='', t=str):
        """Prompt for user input."""
        while True:
            self._stdout.write('%s: ' % msg)
            input = await self._stdin.readline()

            try:
                input = t(input.strip())
                break
            except ValueError:
                self._stdout.write('Invalid data entered.\n')
                continue

        return input

    async def confirm(self, msg='', em=True):
        """Ask for user choice."""
        ans = ['Y', 'N'] if em else ['y', 'n']
        while True:
            self._stdout.write('%s\n' % msg)
            self._stdout.write(
                'Press key: %s \n' % ' / '.join(['Yes', 'No']))
            try:
                self._stdin.channel.set_line_mode(False)
                input = await self._stdin.read(1)
                self._stdin.channel.set_line_mode(True)
            except Exception as e:
                self._stdin.channel.set_line_mode(True)
                raise e

            if input == ans[0]:
                self._stdout.write('Yes\n\n')
                return True
            elif input == ans[1]:
                self._stdout.write('No\n\n')
                return False

        return None

    async def presskey(self, msg='Press any key to continue...'):
        """Press a key to continue."""
        self._stdout.write('%s\n' % msg)

        try:
            self._stdin.channel.set_line_mode(False)
            await self._stdin.read(1)
            self._stdin.channel.set_line_mode(True)

        except Exception as e:
            self._stdin.channel.set_line_mode(True)
            raise e

        return True

    async def choose(self, msg='', choices=[], em=False):
        """Ask for user choice."""
        keylist = {}
        for item in choices:
            if em:
                key = item[0].upper()
            else:
                key = item[0].lower()
            keylist[key] = item

        while True:
            self._stdout.write('%s\n' % msg)
            self._stdout.write('Choices: [ %s ]\n' % ' | '.join(choices))
            self._stdin.channel.set_line_mode(False)
            input = await self._stdin.read(1)
            self._stdin.channel.set_line_mode(True)

            if input in keylist.keys():
                input = keylist[input]
                break
            else:
                self._stdout.write('Invalid choice.\n')

        return input

    async def menu(self, msg='', entries=[], confirm=False):
        """Print menu with entries."""
        entries = entries[:12]
        cnt = 0
        lines = []

        for entry in entries:
            cnt += 1
            lines.append(' {0:>2}. {1}'.format(cnt, entry))

        while True:
            self._stdout.write('{0}\n\n'.format(msg))
            self._stdout.write('\n'.join(lines))
            self._stdout.write('\n\nChoose: ')
            try:
                input = int(await self._stdin.readline())
            except ValueError:
                continue

            if not (1 <= input <= len(entries)):
                self._stdout.write('Invalid choice.\n')
                continue

            if confirm:
                if await self.confirm(
                        'Is ({0}) your final choice?'.format(input), False):
                    break
            else:
                break

        return input - 1

    async def secret(self, msg='Enter password'):
        """Print menu with entries."""
        self._stdout.write('{0}: '.format(msg))

        self._process.channel.set_echo(False)
        try:
            while True:
                input = await self._stdin.readline()
                input = input.strip()
                if input != '':
                    break
            self._process.channel.set_echo(True)
        except Exception as e:
            self._process.channel.set_echo(True)
            raise e

        return input

    @classmethod
    def format(cls, text,
               b=False, d=False, i=False, u=False, bl=False, nv=False):
        """Format terminal text in several ways."""
        codes = ';'.join(filter([
            '1' if b else None,
            '2' if d else None,
            '3' if i else None,
            '4' if u else None,
            '5' if bl else None,
            '7' if nv else None
        ]))
        return '\033[{c}m{t}\033[0m'.format(c=codes if codes else '0', t=text)

    @classmethod
    def bold(cls, text):
        """Make terminal text bold."""
        return cls.format(text, b=True)

    @classmethod
    def dim(cls, text):
        """Make terminal text dim."""
        return cls.format(text, d=True)

    @classmethod
    def italic(cls, text):
        """Make terminal text italic."""
        return cls.format(text, i=True)

    @classmethod
    def underline(cls, text):
        """Make terminal text underline."""
        return cls.format(text, u=True)

    @classmethod
    def blink(cls, text):
        """Make terminal text blink."""
        return cls.format(text, bl=True)

    @classmethod
    def inverse(cls, text):
        """Make terminal text inverse."""
        return cls.format(text, nv=True)

    def exception(self, e):
        """Print exception error message to console."""
        self._stdout.write('\nError: %s\n\n' % e)


class Option:
    """Class representation of one Command option."""

    TYPE_BOOL = 1
    TYPE_CHOICES = 2
    TYPE_VALUE = 3

    def __init__(self,
                 name,
                 abbr=None,
                 type=TYPE_VALUE,
                 choices=[],
                 mandatory=False,
                 default=None,
                 help=''):
        """
        Initialize an Option that belonging to a Command.

        This class configures an option that is used within a command. The
        option is described, configured and evaluated by Option. If the option
        is invalid an exception is raised.

        name        The long name of the option, without double dash '--'.
        abbr        One character abbreviation of the long name, without
                    dash '-'.
        type        The type of option, boolean, choice or value. Use the type
                    constants to select one.
        choices     List of string names for available choices if the type is
                    TYPE_CHOICES.
        mandatory   A boolean describing whether this option should be
                    mandatory.
        default     A default value if the option is not given from the command
                    line.
        help        A helpful description of the option.
        """
        self.name = name
        self.abbr = abbr
        self.type = type
        self.choices = choices
        self.mandatory = mandatory
        self.default = default
        self.help = help

    def _bool(self, opt):
        # Test if one option is given
        if len(opt) is 1:
            # Test if value is given
            if bool(opt[0]) is True:
                raise Util.exception(
                    Error.CMD_OPT_ILLEGAL_VALUE,
                    {'opt': self.name, 'value': opt[0]})
            # Test if only presence is given but no value
            elif bool(opt[0]) is False:
                return True

        # Test if presence is missing
        if len(opt) is 0:
            return False

        raise Util.exception(
            Error.CMD_UNKOWN_ERROR,
            {'opt': self.name, 'value': opt[0], 'type': self.type})

    def _enum(self, opt):
        # Test if one option is given
        if len(opt) is 1:
            # Test if given value is a choice
            if opt[0] not in self.choices:
                raise Util.exception(
                    Error.CMD_OPT_ILLEGAL_CHOICE,
                    {'opt': self.name, 'choice': opt[0]})
            # Test if value is given
            if bool(opt[0]) is True:
                return opt[0]
            else:
                raise Util.exception(
                    Error.CMD_OPT_CHOICE_OMITTED,
                    {'opt': self.name, 'choice': None})

        # Test if presence is missing
        if len(opt) is 0:
            return None

        raise Util.exception(
            Error.CMD_UNKOWN_ERROR,
            {'opt': self.name, 'value': opt[0], 'type': self.type})

    def _value(self, opt):
        # Test if one option is given
        if len(opt) is 1:
            # Test if value is given
            if bool(opt[0]) is True:
                return opt[0]
            else:
                raise Util.exception(
                    Error.CMD_OPT_VALUE_OMITTED,
                    {'opt': self.name, 'value': None})

        # Test if presence is missing
        if len(opt) is 0:
            return None

        raise Util.exception(
            Error.CMD_UNKOWN_ERROR,
            {'opt': self.name, 'value': opt[0], 'type': self.type})

    def evaluate(self, opts):
        """Evaluate options."""
        opt = []
        for r in opts:
            if r[0] == str('--'+self.name) or r[0] == ('-'+str(self.abbr)):
                opt.append(r[1])

        # Test if not single
        if len(opt) > 1:
            raise Util.exception(
                Error.CMD_OPT_MULTIPLE_VALUES,
                {'opt': self.name, 'tot_num': len(opt)})

        # Test whether given if mandatory
        if self.mandatory is True and len(opt) is 0:
            raise Util.exception(
                Error.CMD_OPT_MANDATORY_OMITTED, {'opt': self.name})

        # Test if there is a default and none given
        if self.default is not None and len(opt) is 0:
            return self.default

        value = None
        if self.type is Option.TYPE_BOOL:
            value = self._bool(opt)
        elif self.type is Option.TYPE_CHOICES:
            value = self._enum(opt)
        elif self.type is Option.TYPE_VALUE:
            value = self._value(opt)
        else:
            raise Util.exception(
                Error.CMD_OPT_TYPE_INVALID,
                {'opt': self.name, 'type': self.type})

        return (self.name, value)


class Command(FactoryInterface):
    """Representation of one executable command."""

    """A abbreviated description of the command for the list section"""
    abbr = ''

    """Long description explaining the command"""
    description = ''

    def __init__(self, cmd, io):
        """Initialize Command class."""
        self.command = cmd
        self._io = io

        self.__opts = self._options() + [Option(
            'help',
            abbr='h',
            type=Option.TYPE_BOOL,
            help='Print the command help section')]

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return []

    async def execute(self, opts):
        """Execute a command with current options."""
        opts = self._evaluate(opts)

        if opts['help']:
            self._help()
        else:
            await self._command(opts)

    def _evaluate(self, opts):
        options = {}
        for opt in self.__opts:
            (k, v) = list(opt.evaluate(opts))
            options[k] = v
        return options

    def _help(self):
        """
        Print help section.

        @todo Redo this with nice tabing, format:
        <name>: (Long description)

        *    name   abbr       expr     def    desc
        --------------------------------------------------
             help   --help/-h  (n/a)    (n/a)  (help...)
        """
        rows = []

        # Loop through option cols and create rows
        for opt in self.__opts:
            if opt.type == Option.TYPE_VALUE:
                expr = opt.name.upper()
            elif opt.type == Option.TYPE_CHOICES:
                expr = '(' + '|'.join(opt.choices) + ')'
            else:
                expr = ''
            if not isinstance(opt.abbr, str):
                flag = '--' + opt.name
            else:
                flag = '--' + opt.name + '/-' + opt.abbr
            rows.append((
                '*' if bool(opt.mandatory) is True else '',
                opt.name,
                flag,
                expr,
                '' if bool(opt.default) is False else str(opt.default),
                opt.help))

        # Calculate the max width of each column
        width = [0, 0, 0, 0, 0, 0]
        for col in range(6):
            chars = 0
            for row in rows:
                roww = len(row[col])
                if roww > chars:
                    chars = roww
            width[col] = chars

        r_b = ''
        for row in rows:
            for col in range(6):
                r_b += row[col] + ' '*(
                    width[col] - len(row[col]) + 2)
            r_b += Shell.EOL

        b = Shell.EOL + self.description + Shell.EOL*2
        b += '<' + self.command + '> supports the options below' + Shell.EOL
        b += '-'*79 + Shell.EOL
        b += r_b + Shell.EOL
        self._io << b

    async def _command(self, opts):
        """
        Complete the command.

        Override this method and implement command logichere.
        """
        pass


class Shell(ContainerAware):
    """Shell that represents a PTY."""

    cmd_regex = '^(\w+)'
    opt_regex = '(?<=\s)((?:-\w(?!\w))|(?:--\w+))(?:(?:[ ]+|=)' \
                '(?:(?:"((?<=")\S+(?="))")|(?![\-|"])(:?\S+)))?'
    EOL = '\r\n'

    def __init__(self, commands, ioc, process):
        """
        Initialize the shell.

        Loads the commands and the input/output streams.
        """
        Util.is_type(commands, list)
        ContainerAware.__init__(self, ioc)
        self._process = process
        self._io = ConsoleIO(process)
        self.__cmds = {}

        for klass in commands:
            Util.is_class(klass, Command)
            command = klass.factory(ioc=self.ioc, io=self._io)
            self._add(command)

        self._add(Shell.ClearCommand(self._io))
        self._add(Shell.ExitCommand(self._io))
        self._add(Shell.HelpCommand(self._io, self.__cmds))

    def _add(self, cmd):
        if cmd.command in self.__cmds:
            raise Util.exception(
                Error.CMD_SHELL_DUPLICATE,
                {'package': Util.class_pkg(cmd), 'command': cmd.command})

        self.__cmds[cmd.command] = cmd

    async def execute(self, line):
        """Interpret one line of text in the shell."""
        if bool(line.strip()) is False:
            raise Util.exception(Error.CMD_SHELL_EMPTY)

        cmd = re.findall(self.cmd_regex, line)
        if len(cmd) is not 1:
            raise Util.exception(
                Error.CMD_SHELL_CONFUSED, {'line': line})
        cmd = cmd[0]

        if cmd not in self.__cmds:
            raise Util.exception(
                Error.CMD_SHELL_INVALID_COMMAND, {'command': cmd})

        opts = re.findall(self.opt_regex, line)
        opts = self._parse(opts)

        try:
            await self.__cmds[cmd].execute(opts)
        except asyncssh.BreakReceived as e:
            self._io << '\n\nAbort sequence received!\n%s\n\n' % e

    def _parse(self, options):
        opts = []
        for opt in options:
            opts.append(
                (opt[0], opt[1] if bool(opt[1]) is not False else opt[2]))
        return opts

    class HelpCommand(Command):
        """Print help text about a command."""

        abbr = 'Print available commands and how to use them.'
        description = """Help will print all the available commands loaded in
the console shell"""

        def __init__(self, io, cmds):
            """Initialize the command. Takes a list of Command classes."""
            Command.__init__(self, 'help', io)
            self.__cmds = cmds

        async def _command(self, opts):
            rows = []
            for cmd in self.__cmds:
                rows.append('{n:<16}{d}'.format(
                    n=self.__cmds[cmd].command, d=self.__cmds[cmd].abbr))

            self._io << (
                Shell.EOL +
                'Available commands with description below.' + Shell.EOL +
                '-'*79 + Shell.EOL +
                Shell.EOL.join(rows) + Shell.EOL*2 +
                'type <command> -h for detailed help.' + Shell.EOL*2)

    class ExitCommand(Command):
        """Exit the shell."""

        abbr = 'Exit the current terminal session.'
        description = """Exit will exit the console session and restore the
screen"""

        def __init__(self, io):
            """Initialize the command."""
            Command.__init__(self, 'exit', io)

        async def _command(self, opts):
            raise Util.exception(Error.CMD_SHELL_EXIT)

    class ClearCommand(Command):
        """Clear the screen."""

        abbr = 'Clear the terminal window.'
        description = """Clear clears the console screen/window"""

        def __init__(self, io):
            """Initialize the command. Takes a list of Command classes."""
            Command.__init__(self, 'clear', io)

        async def _command(self, opts):
            self._io << '\033[H\033[J'


class Terminal(Shell):
    """Asynchronoius instance of Shell."""

    __lock = asyncio.Lock()

    def __init__(self, commands, ioc, process):
        """Initialize Terminal from SSHServerProcess."""
        Shell.__init__(self, commands, ioc, process)
        self._config = self.ioc.config['terminal']

    async def run(self):
        """Looping the Shell interpreter."""
        if self.__lock.locked():
            self._process.close()
            return

        async with self.__lock:
            try:

                self._io << (
                    '\033[41m\033[H\033[J' + self._config['message'] +
                    Shell.EOL + '='*79 + Shell.EOL)
                self._io << self._config['prompt']

                while not self._io._stdin.at_eof():
                    try:

                        line = await self._io._stdin.readline()
                        await self.execute(line.strip())

                    except CmdShellInvalidCommand as exc:
                        self._io << (
                            str(exc) + Shell.EOL +
                            'Try "help" or "<command> -h"' + Shell.EOL*2)
                    except CmdShellEmpty:
                        pass
                    except asyncssh.TerminalSizeChanged:
                        self._io._upd_size()
                        continue
                    except CmdShellExit:
                        break
                    except Exception as e:
                        self._io << ('%s: %s \n' % (type(e), e))
                        logging.exception(e)

                    self._io << self._config['prompt']

            except asyncssh.BreakReceived:
                pass

            self._io << '\033[40m\033[H\033[J'
            self._process.close()
