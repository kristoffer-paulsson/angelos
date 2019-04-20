"""Module docstring."""
import types
from .utils import Util
from .error import Error


class Container:
    """IoC container class."""

    def __init__(self, config={}):
        """Initialize container with dictionary of values and lambdas."""
        Util.is_type(config, dict)

        self.__config = config
        self.__instances = {}

    def __getattr__(self, name):
        """Get attribute according to container configuration."""
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

    def add(self, name, value):
        """Add a service with name and value/lambda after initialization."""
        if name in self.__config:
            raise IndexError('Service already configured')
        else:
            self.__config[name] = value


class ContainerAware:
    """Mixin that makes a class IoC aware."""

    def __init__(self, ioc):
        """Initialize a class with IoC awareness."""
        Util.is_type(ioc, Container)
        self.__ioc = ioc

    @property
    def ioc(self):
        """Container property access."""
        return self.__ioc
