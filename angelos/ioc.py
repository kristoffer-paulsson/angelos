"""Module docstring."""
import types
from .utils import Util
from .error import Error


class Container:
    """Docstring"""
    def __init__(self, config={}):
        """Docstring"""
        Util.is_type(config, dict)

        self.__config = config
        self.__instances = {}

    def __getattr__(self, name):
        """Docstring"""
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


class ContainerAware:
    def __init__(self, ioc):
        self.__ioc = ioc

    @property
    def ioc(self):
        return self.__ioc
