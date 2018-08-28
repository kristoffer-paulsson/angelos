from ..utils import Util
from ..ioc import Service, Container
from ..cmd import Command





class Settings(Service):
    def __init__(self, name, params):
        Util.is_type(params, dict)
        Service.__init__(self, name)
        self.__params = params

    def params(self):
        return list(self.__params.keys())

    def get(self, name):
        """
        Returns a parameter based on a key name.
        name    string Name key of parameter to return
        return    Returns parameter or None if no paramater
        """
        Util.is_type(name, str)
        if name in self.__params:
            return self.__params[name]
        return None

    def set(self, name, value):
        Util.is_type(name, str)
        Util.is_type(value, (str, int, float))

        if name in self.__params:
            self.__params[name] = value
        else:
            raise Util.format_exception(
                KeyError,
                self.__class__.__name__,
                'Setting parameter not found',
                {'key': name, 'value': value}
            )

    @staticmethod
    def factory(**kwargs):
        Util.is_type(kwargs, dict)
        Util.is_type(kwargs['name'], str)
        Util.is_type(kwargs['params'], dict)

        return Settings(kwargs['name'], kwargs['params'])
