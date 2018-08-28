import argparse
import cmd
from ..common import logger
from ..utils import Utils
from ..task import Task
from ..cmd import CMD, Command
from ..ioc import Container

SHELL_HELP = """
The following commands are built in and can help you accordingly:
-----------------------------------------------------------------
list           Lists all available commands in the console
help           Shows a commands help section, or this one
quit           Shuts down the current software
"""


class Console(cmd.Cmd, Task):
    NAME = 'Console'

    intro = 'Angelos safe messaging server'
    prompt = 'Angelos 0.1dX > '

    def __init__(self, name, sig, ioc, cmd_service):
        cmd.Cmd.__init__(self)
        self.__cmds = {}
        self.__parser = argparse.ArgumentParser('')

        Task.__init__(self, name, sig)
        Util.is_type(ioc, Container)
        Util.is_type(cmd_service, CMD)
        self.__ioc = ioc

        cmds = cmd_service.commands()
        subp = self.__parser.add_subparsers()

        for c in cmds:
            klass = Util.imp_pkg(c)
            Util.is_class(klass, Command)
            command = klass.factory(ioc=self.__ioc)
            name = command.name()
            if name in self.__cmds:
                raise Util.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Couldn\'t add command, because of duplicate.',
                    {'command': name}
                )
            command.parser(subp)
            self.__cmds[name] = command
            logger.debug(Util.format_info(
                'Command registered with console shell',
                {'command': command.name(), 'path': c})
            )

    def default(self, line):
        try:
            args = self.__parser.parse_args(line.split())
            if hasattr(args, 'func'):
                return args.func(args)
            else:
                cmd.Cmd.default(self, line)
        except SystemExit:
            pass

    def do_help(self, arg):
        self.stdout.write('\nThe current commands are available:')
        self.stdout.write('Enter "<command> -h" to get help.\n' + '-'*35)
        self.stdout.write('\n'.join(list(self.__cmds.keys())) + '\n\n')

    def emptyline(self):
        pass

    def _initialize(self):
        if self.intro:
            self.stdout.write(str(self.intro)+'\n')

    def _finalize(self):
        self.postloop()

    def work(self):
        stop = False
        if self.cmdqueue:
            line = self.cmdqueue.pop(0)
        else:
            if self.use_rawinput:
                try:
                    line = input(self.prompt)
                except EOFError:
                    line = 'EOF'
            else:
                self.stdout.write(self.prompt)
                self.stdout.flush()
                line = self.stdin.readline()
                if not len(line):
                    line = 'EOF'
                else:
                    line = line.rstrip('\r\n')
        line = self.precmd(line)
        stop = self.onecmd(line)
        stop = self.postcmd(stop, line)
        if bool(stop):
            self._done()
