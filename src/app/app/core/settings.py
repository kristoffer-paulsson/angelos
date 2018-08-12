import types
from ..utils import Utils
from ..ioc import Service, Container
from ..cmd import Command


class EnvCommand(Command):
    cmd = 'env'
    short = 'Manipulates environment settings'

    def __init__(self, environment):
        Command.__init__(self)
        Utils.is_type(environment, Settings)
        self.__env = environment

    def _arguments(self, parser):
        parser.add_argument('op', nargs=1, choices=['list', 'get', 'set'],
                            help='parameter operations')
        parser.add_argument('key', nargs='?', help='parameter key')
        parser.add_argument('value', nargs='?', help='parameter value')

    def _execute(self, args):
        if 'set' in args.op:
            if not args.key:
                print 'You must enter a key'
                return
            if not args.value:
                print 'You must enter a value'
                return
            if args.key in self.__env.params():
                self.__env.set(args.key, args.value)
                print 'Parameter {:} set to: "{:}"'.format(
                    args.key, args.value
                )
            else:
                print 'Environment setting "' + args.key + '" is invalid'
        elif 'get' in args.op:
            if not args.key:
                print 'You must enter a key'
                return
            if args.key in self.__env.params():
                print '{:}'.format(self.__env.get(args.key))
            else:
                print 'Environment setting "' + args.key + '" is invalid'
        elif 'list' in args.op:
            for p in self.__env.params():
                print '{:}={:}'.format(p, self.__env.get(p))

    @staticmethod
    def factory(**kwargs):
        Utils.is_type(kwargs, types.DictType)
        Utils.is_type(kwargs['ioc'], Container)

        return EnvCommand(kwargs['ioc'].service('environment'))


class Settings(Service):
    def __init__(self, name, params):
        Utils.is_type(params, types.DictType)
        Service.__init__(self, name)
        self.__params = params

    def params(self):
        return self.__params.keys()

    def get(self, name):
        """
        Returns a parameter based on a key name.
        name    string Name key of parameter to return
        return    Returns parameter or None if no paramater
        """
        Utils.is_type(name, types.StringType)
        if name in self.__params:
            return self.__params[name]
        return None

    def set(self, name, value):
        Utils.is_type(name, types.StringType)
        Utils.is_type(value,
                      (types.StringType, types.IntType, types.FloatType))

        if name in self.__params:
            self.__params[name] = value
        else:
            raise Utils.format_exception(
                KeyError,
                self.__class__.__name__,
                'Setting parameter not found',
                {'key': name, 'value': value}
            )

    @staticmethod
    def factory(**kwargs):
        Utils.is_type(kwargs, types.DictType)
        Utils.is_type(kwargs['name'], types.StringType)
        Utils.is_type(kwargs['params'], types.DictType)

        return Settings(kwargs['name'], kwargs['params'])
