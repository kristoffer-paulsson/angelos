import types
from .utils import Util
from .error import Error


class Container:
    def __init__(self, config={}):
        Util.is_type(config, dict)

        self.__config = config
        self.__instances = {}

    def __getattr__(self, name):
        if name not in self.__instances:
            if name not in self.__config:
                raise Util.exception(
                    Error.IOC_NOT_CONFIGURED, {'service': name})
            elif isinstance(self.__config[name], types.LambdaType):
                self.__instances[name] = self.__config[name](self)
            else:
                raise Util.exception(
                    Error.IOC_LAMBDA_EXPECTED, {'service': name})
        return self.__instances[name]
