import os
import sys
import logging
import importlib

"""
The utils.py module is the module that containse all minor extras that is used
globally in the application
"""


class Utils:
    """@todo"""
    __app_path = os.path.dirname(os.path.abspath(sys.argv[0]))
    __usr_path = os.path.expanduser('~')
    __exe_path = os.path.abspath(os.getcwd())

    @staticmethod
    def app_dir():
        """
        Absolute path to the executed scripts location.
        """
        return Utils.__app_path

    @staticmethod
    def usr_dir():
        """
        Absolute path to user home directory.
        """
        return Utils.__usr_path

    @staticmethod
    def exe_dir():
        """
        Absolute path to current working directory.
        """
        return Utils.__exe_path

    @staticmethod
    def is_type(instance, type):
        """
        check_type is a helper function. Tests for an instance and raises a
        standardized TypeError exception.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them

        Example:
        check_type(result, (NoneType, StringType))
        """
        if not isinstance(instance, type):
            raise TypeError(
                'Instance expected type {0}, but got: {1}',
                type(type),  type(instance)
            )

    @staticmethod
    def is_class(instance, type):
        """
        check_class is a helper function. Tests for a subclass and raises a
        standardized TypeError exception.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them

        Example:
        check_class(result, (Model, BaseModel))
        """
        if not issubclass(instance, type):
            raise TypeError(
                'Subclass expected type {0}, but got: {1}',
                type(type), type(instance)
            )

    @staticmethod
    def format_exception(exception_type,
                         class_name='No classname',
                         message='Formated exception',
                         debug_info={}):
        """
        format_exception is a helper function. It will populate and format an
        exception so that it is understandable and include good debug data.

        exception_type  Requiers an exception type
        class_name      The class name of current class, or of current
                        instance
        message         Simple error message
        debug_info      A dictionary of interesting debug values
        returns         A string to enter into exception

        Example:
        raise format_exception(
            RuntimeError,
            self.__class__.__name__,
            'Unexpected result',
            {
                id: 45654654767,
                user: 'User Name'
            }
        )
        """
        Utils.is_class(exception_type, Exception)
        Utils.is_type(class_name, str)
        Utils.is_type(message, str)
        Utils.is_type(debug_info, dict)

        debug = []
        for k in debug_info:
            debug.append('{0}: {1}'.format(k, debug_info[k]))
        exc = exception_type('{0}, "{1}" - debug: ({2})'.format(
            class_name, message, ', '.join(debug)
        ))
        return exc

    @staticmethod
    def format_info(event_str, data={}):
        """
        log_format_info is a helper function. It will format an info message
        with support for event data.

        event_str            A string describing the event
        data                A dictionary with info
        returns                string to pass to logger.info()

        Example:
        try:
            ...
        except Exception as e:
            logger.warning(log_format_info(
                e, 'Result missing from function call X'
            ), exc_info=True)
        """
        Utils.is_type(event_str, str)
        Utils.is_type(data, (dict, type(None)))

        if not data:
            return '{0}.'.format(event_str)
        else:
            info = []
            for k in data:
                info.append('{0}: {1}'.format(k, data[k]))
                return '{0}. Info: ({1})'.format(event_str, ', '.join(info))

    @staticmethod
    def format_error(caught_exception, event_str):
        """
        log_format_error is a helper function. It will format an exception and
        message formatted with help of format_exception().

        caught_exception    An exception
        event_str            A string describing the event
        returns                string to pass to logger.error()

        Example:
        try:
            ...
        except Exception as e:
            logger.warning(log_format_error(
                e, 'Result missing from function call X'
            ), exc_info=True)
        """
        Utils.is_type(caught_exception, Exception)
        Utils.is_type(event_str, str)

        return '{0}, Class: {1}:{2}'.format(
            event_str,
            str(type(caught_exception)),
            caught_exception
        )

    @staticmethod
    def imp_pkg(path):
        """
        imp_pkg is a helper function for importing classes dynamically by
        telling the search path
        path        String that tells where to find the class
        return        Returns a class descriptor

        Example:
        klass = Utils.imp_pkg('module.package.Class')
        c_instance = klass()
        """
        Utils.is_type(path, str)
        pkg = path.rsplit('.', 1)
        return getattr(importlib.import_module(pkg[0]), pkg[1])

    @staticmethod
    def hours(seconds):
        if seconds > 24*3600:
            return '{:>7.2}d'.format(float(seconds/(24*3600)))
        else:
            seconds = int(seconds)
            h = int(seconds / 3600)
            m = int(seconds / 60)
            s = seconds - h*3600 - m*60
            return '{:}:{:02}:{:02}'.format(h, m, s)


class Log():
    def __init__(self, config={}):
        Utils.is_type(config, dict)
        if not os.path.exists(config['path']):
            raise ValueError('Path is not an existing file.')

        self.__format = '%(asctime)s %(levelname)s %(message)s'
        self.__path = config['path']

        self.__app = self.__logger('app', 'error', logging.DEBUG)
        self.__bizz = self.__logger('biz', 'bizz', logging.DEBUG)
        # logging.basicConfig(filename=self.__path + '/error.log',
        #                    level=logging.DEBUG)

    def __logger(self, name, file, level):
        """
        Created and instanciates a logger
        name        String with name of logger
        file        String with filename for log file
        level        Log level
        """
        logger = logging.getLogger(name)
        hdlr = logging.FileHandler(
            self.__path + '/' + file + '.log', mode='a+'
        )
        formatter = logging.Formatter(self.__format)
        hdlr.setFormatter(formatter)
        logger.addHandler(hdlr)
        logger.setLevel(level)
        return logger

    def app_logger(self):
        """
        Return the app logger that logs application execution
        """
        return self.__app

    def bizz_logger(self):
        """Return the bizz logger that logs application business logic"""
        return self.__bizz


class FactoryInterface:
    @staticmethod
    def factory(**kwargs):
        raise NotImplementedError()
