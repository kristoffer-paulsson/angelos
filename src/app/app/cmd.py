import types
from .utils import Utils
from .ioc import Service, Initializer


class Command:
    """command sets the 'command' in the interpreter"""
    cmd = ''

    """A short description of the command for the list section"""
    short = ''

    def __init__(self):
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

    def name(self):
        return self.cmd

    def help(self):
        return self.short

    @staticmethod
    def factory(ioc):
        raise NotImplementedError()


class CMD(Service):
    def __init__(self, name, commands):
        Utils.is_type(commands, types.ListType)
        Service.__init__(self, name)
        self.__commands = commands

    def commands(self):
        return self.__commands


class CMDInitializer(Initializer):
    def service(self, name):
        Utils.is_type(name, types.StringType)

        return CMD(name, self._params['commands'])

    def _check_params(self):
        pass
