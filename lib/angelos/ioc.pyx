# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
import logging
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
            elif callable(self.__config[name]):
                try:
                    self.__instances[name] = self.__config[name](self)
                except Exception as e:
                    logging.exception(e)
                    raise e
            else:
                raise Util.exception(
                    Error.IOC_LAMBDA_EXPECTED, {'service': name})
        return self.__instances[name]


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


class Config:
    def __load(self, filename):
        pass

    def __config(self):
        return {}


class Handle:
    """Handle for late IoC services."""

    def __init__(self, _type):
        """Init handle by setting allowed type."""
        self.__type = _type
        self.__value = None
        self.__name = None

    def __get__(self, instance, owner):
        """Return None if not set or the correct instance."""
        return self.__value

    def __set__(self, instance, value):
        """
        Set the handle instance.

        Handle is immutable and can only be set once.
        """
        Util.is_type(value, self.__type)
        self.__value = value

    def __delete__(self, instance):
        """Handle can not be deleted. It is immutable."""
        raise ValueError('Can not delete handle for %s' % self.__name)

    def __set_name__(self, owner, name):
        """Set the attribute name."""
        self.__name = name


class StaticHandle(Handle):

    def __set__(self, instance, value):
        """
        Set the handle instance.

        Handle is immutable and can only be set once.
        """
        if self.__value: raise ValueError(  # noqa E701
            'Handle already set for %s' % self.__name)
        Util.is_type(value, self.__type)
        self.__value = value
