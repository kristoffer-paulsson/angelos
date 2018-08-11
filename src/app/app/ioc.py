import types
import importlib
from .utils import Utils


class Service:
    """
    Service is a base class for Application services.
    """
    def __init__(self, name):
        Utils.is_type(name, types.StringType)
        self.__name = name

    def name(self):
        """
        Name of the service
        return    Returns a string that is the name of the service
        """
        return self.__name


class Initializer:
    def __init__(self, ioc, params):
        """
        Initializes the service Initializer class.
        ioc        Is the the service container instance
        config     Is a Dictionary of parameter settings for the service
        """
        Utils.is_type(ioc, Container)
        Utils.is_type(params, types.DictType)

        self._ioc = ioc
        self._params = params
        self._check_params()

    def _check_params(self):
        pass

    def service(self, name):
        """
        service() method initializes the actual service instance, using the
        container and config parameters.
        return    Returns the instanciated Service
        """
        raise NotImplementedError()


class Container:
    """
    Container is a Service container implemented according to the koncept of
    IoC
    """

    def __init__(self, config):
        """
        Initialization of the Container requires the configuration to be loaded
        and returned.
        config        Dictionary of configuration values
        """
        Utils.is_type(config, types.DictType)
        self.__config = config
        self.__services = {}

    def service(self, name):
        Utils.is_type(name, types.StringType)

        if name in self.__services:
            return self.__services[name]
        else:
            if name not in self.__config:
                raise Utils.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Requested service is not configured',
                    {'name': name}
                )

            conf = self.__config[name]
            if 'class' not in conf:
                raise Utils.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Service initializer configuration class not specified',
                    {'name': name}
                )
            path = conf['class'] + 'Initializer'
            params = conf['params'] if 'params' in conf else {}

            try:
                pkg = path.rsplit('.', 1)
                klass = getattr(importlib.import_module(pkg[0]), pkg[1])
            except ImportError:
                raise Utils.format_exception(
                    RuntimeError,
                    self.__class__.__name__,
                    'Service class not found.',
                    {'class': str(conf['class'])}
                )

            Utils.is_class(klass, Initializer)
            service = klass(self, params).service(name)

            self.__services[service.name()] = service
            return self.__services[name]

    def config(self):
        return self.__config
