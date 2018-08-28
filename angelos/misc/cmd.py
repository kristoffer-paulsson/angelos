import argparse
from ..utils import Util, FactoryInterface
from ..error import Error
from ..ioc import Container


class Command(FactoryInterface):
    """command sets the 'command' in the interpreter"""
    cmd = ''

    """A short description of the command for the list section"""
    short = ''

    def __init__(self, adapter):
        Util.is_type(adapter, ConsoleAdapter)

        self.__adapter = adapter
        self.__parsed = False

    def parser(self, subp):
        if self.__parsed:
            return
        parser = subp.add_parser(self.cmd, help=self.short)
        self._arguments(parser)
        parser.set_defaults(func=self._execute)
        self.__parsed = True

    def _execute(self, args):
        raise NotImplementedError()

    def _arguments(self, args):
        raise NotImplementedError()

    def _adapter(self):
        return self.__adapter

    def name(self):
        return self.cmd

    def help(self):
        return self.short


class Shell:
    def __init__(self, ioc, commands, adapter):
        self.__cmds = {}
        self.__parser = argparse.ArgumentParser('')

        Util.is_type(adapter, ConsoleAdapter)
        Util.is_type(commands, list)
        Util.is_type(ioc, Container)
        self.__ioc = ioc

        subp = self.__parser.add_subparsers()

        for cmd in commands:
            klass = Util.imp_pkg(cmd)
            Util.is_class(klass, Command)
            command = klass.factory(ioc=self.__ioc, adapter=adapter)
            name = command.name()
            Util.exception(
                Error.COMMAND_ALREADY_REGISTERED,
                {'package': cmd, 'name': name})
            command.parser(subp)
            self.__cmds[name] = command

    def execute(self, line):
        Util.is_type(line, str)
        args = self.__parser.parse_args(line.split())
        if hasattr(args, 'func'):
            return args.func(args)


class ConsoleAdapter:
    def __init__(self, stdin, stdout):
        self.stdin = stdin
        self.stdout = stdout
