from .utils import Utils, FactoryInterface
from .ioc import Service


class Command(FactoryInterface):
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


class CMD(Service):
    def __init__(self, name, commands):
        Utils.is_type(commands, list)
        Service.__init__(self, name)
        self.__commands = commands

    def commands(self):
        return self.__commands

    @staticmethod
    def factory(**kwargs):
        Utils.is_type(kwargs, dict)
        Utils.is_type(kwargs['name'], str)
        Utils.is_type(kwargs['params'], dict)

        return CMD(kwargs['name'], kwargs['params']['commands'])
