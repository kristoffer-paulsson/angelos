"""Module docstring."""
import re
import sys
from ..utils import Util, FactoryInterface
from ..error import Error
from ..ioc import ContainerAware


class Option:
    """Class representation of one Command option."""

    TYPE_BOOL = 1
    TYPE_CHOISES = 2
    TYPE_VALUE = 3

    def __init__(self,
                 name,
                 short=None,
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
        short       One character abbreviation of the long name, without
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
        self.short = short
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
            # Test if given value is a choise
            if opt[0] not in self.choices:
                raise Util.exception(
                    Error.CMD_OPT_ILLEGAL_CHOISE,
                    {'opt': self.name, 'choise': opt[0]})
            # Test if value is given
            if bool(opt[0]) is True:
                return opt[0]
            else:
                raise Util.exception(
                    Error.CMD_OPT_CHOISE_OMITTED,
                    {'opt': self.name, 'choise': None})

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
            if r[0] == str('--'+self.name) or r[0] == ('-'+str(self.short)):
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
        elif self.type is Option.TYPE_CHOISES:
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

    """A short description of the command for the list section"""
    short = ''

    """Long description explaining the command"""
    description = ''

    def __init__(self, cmd):
        """Initialize Command class."""
        self.command = cmd

        self._stdin = None
        self._stdout = None

        self.__opts = [Option(
            'help',
            short='h',
            type=Option.TYPE_BOOL,
            help='Prints the command help section')]

        self.__opts += self._options()

    def _options(self):
        """
        Return a list of Option class configurations.

        Overide this method.
        """
        return []

    def execute(self, opts, stdin=sys.stdin, stdout=sys.stdout):
        """Execute a command with current options."""
        self._stdin = stdin
        self._stdout = stdout

        opts = self._evaluate(opts)

        if opts['help']:
            self._help()
        else:
            self._command(opts)

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
            elif opt.type == Option.TYPE_CHOISES:
                expr = '(' + '|'.join(opt.choices) + ')'
            else:
                expr = ''
            if not isinstance(opt.short, str):
                flag = '--' + opt.name
            else:
                flag = '--' + opt.name + '/-' + opt.short
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
        b += '<' + self.command + '> support the options below' + Shell.EOL
        b += '='*79 + Shell.EOL
        b += r_b + Shell.EOL
        self._stdout.write(b)

    def _command(self, opts):
        """
        Complete the command.

        Override this method and implement command logichere.
        """
        pass


class Shell(ContainerAware):
    """Shell that represents a PTY."""

    cmd_regex = """^(\w+)"""
    opt_regex = """(?<=\s)((?:-\w(?!\w))|(?:--\w+))(?:(?:[ ]+|=)(?:(?:"((?<=")\S+(?="))")|(?![\-|"])(:?\S+)))?"""  # noqa E501
    EOL = '\r\n'

    def __init__(self, commands, ioc, stdin=sys.stdin, stdout=sys.stdout):
        """
        Initialize the shell.

        Loads the commands and the input/output streams.
        """
        Util.is_type(commands, list)
        ContainerAware.__init__(self, ioc)
        self.__stdin = stdin
        self.__stdout = stdout
        self.__cmds = {}

        for cmd in commands:
            # klass = Util.imp_pkg(cmd)
            klass = cmd
            Util.is_class(klass, Command)
            command = klass.factory(ioc=self.__ioc)
            self._add(command)

        self._add(Shell.ClearCommand())
        self._add(Shell.ExitCommand())
        self._add(Shell.HelpCommand(self.__cmds))

    def _add(self, cmd):
        if cmd.command in self.__cmds:
            raise Util.exception(
                Error.CMD_SHELL_DUPLICATE,
                {'package': Util.class_pkg(cmd), 'command': cmd.command})

        self.__cmds[cmd.command] = cmd

    def execute(self, line):
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

        self.__cmds[cmd].execute(opts, self.__stdin, self.__stdout)

    def _parse(self, options):
        opts = []
        for opt in options:
            opts.append((opt[0],
                         opt[1] if bool(opt[1]) is not False else opt[2]))
        return opts

    class HelpCommand(Command):
        """Print help text about a command."""

        short = 'Prints available commands and how to use them.'
        description = """Help will print all the available commands loaded in
the console shell"""

        def __init__(self, cmds):
            """Initialize the command. Takes a list of Command classes."""
            Command.__init__(self, 'help')
            self.__cmds = cmds

        def _command(self, opts):
            rows = []
            for cmd in self.__cmds:
                rows.append('{n:<16}{d}'.format(
                    n=self.__cmds[cmd].command, d=self.__cmds[cmd].short))

            b = Shell.EOL
            b += 'Available commands with description below.' + Shell.EOL
            b += '='*79 + Shell.EOL
            b += Shell.EOL.join(rows) + Shell.EOL*2
            b += 'type <command> -h for detailed help.' + Shell.EOL*2
            self._stdout.write(b)

    class ExitCommand(Command):
        """Exit the shell."""

        short = 'Exits the current terminal session.'
        description = """Exit will exit the console session and restore the
screen"""

        def __init__(self):
            """Initialize the command."""
            Command.__init__(self, 'exit')

        def _command(self, opts):
            raise Util.exception(Error.CMD_SHELL_EXIT)

    class ClearCommand(Command):
        """Clear the screen."""

        short = 'Clears the terminal window.'
        description = """Clear clears the console screen/window"""

        def __init__(self):
            """Initialize the command. Takes a list of Command classes."""
            Command.__init__(self, 'clear')

        def _command(self, opts):
            self._stdout.write('\033[H\033[J')
