from .utils import Utils, FactoryInterface


class Service(FactoryInterface):
    """
    Service is a base class for Application services.
    """
    def __init__(self, name):
        Utils.is_type(name, str)
        self.__name = name

    def name(self):
        """
        Name of the service
        return    Returns a string that is the name of the service
        """
        return self.__name


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
        Utils.is_type(config, dict)
        self.__config = config
        self.__services = {}

    def service(self, name):
        Utils.is_type(name, str)

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
            path = conf['class']
            params = conf['params'] if 'params' in conf else {}

            service = Utils.imp_pkg(path).factory(name=name,
                                                  ioc=self,
                                                  params=params)

            self.__services[service.name()] = service
            return self.__services[name]

    def config(self):
        return self.__config
