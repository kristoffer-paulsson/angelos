# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
The Inversion of Control (IoC) framework is used as a central part of both
the server and client. It is used to start application services and make them
available in the whole application.
 """
import logging
from typing import Any
from .utils import Util
from .error import Error


class Container:
    """
    The IoC Container class is responsible for initializing and globally
    enabling access to application services.

    Parameters
    ----------
    config : dict
        The configuration being loaded into the IoC.

    Attributes
    ----------
    __config : dict
        Internal IoC configuration.
    __instances : dict
        Instanced application services.
    """

    def __init__(self, config: dict={}):
        self.__config = config
        self.__instances = {}

    def __getattr__(self, name: str) -> Any:
        if name not in self.__instances:
            if name not in self.__config:
                raise Util.exception(
                    Error.IOC_NOT_CONFIGURED, {"service": name}
                )
            elif callable(self.__config[name]):
                try:
                    self.__instances[name] = self.__config[name](self)
                except Exception as e:
                    logging.exception(e)
                    raise e
            else:
                raise Util.exception(
                    Error.IOC_LAMBDA_EXPECTED, {"service": name}
                )
        return self.__instances[name]

    def __iter__(self):
        for instance in self.__instances.values():
            yield instance


class ContainerAware:
    """Mixin that makes its inheritors aware of the IoC container.

    Parameters
    ----------
    ioc : Container
        The IoC Container.

    Attributes
    ----------
    __ioc : type
        Internal reference to the IoC.
    """

    def __init__(self, ioc: Container):
        self.__ioc = ioc

    @property
    def ioc(self) -> Container:
        """Makes the IoC container accessible publically.

        Returns
        -------
        Container
            The IoC container.

        """
        return self.__ioc


class Config:
    """
    Mixin for a Configuration class that might load and prepare the Container.
    """

    def __load(self, filename: str) -> dict:
        return {}

    def __config(self) -> dict:
        return {}


class Handle:
    """
    The Handle class allows application services to be instanciated at a later
    state, rather than on boot. This allows processes that are dependent on
    user input to make choises about services at runtime. The service in this
    handle can be set multiple times.
    Handle implements the Descriptor Protocol.

    Parameters
    ----------
    _type : Any
        The service class type that should be put here.

    Attributes
    ----------
    __type : Any
        Internally the class type supported at runtime.
    __value : Any
        Internally the instance of the application service class.
    __name : str
        Internally the name of the service.
    """

    def __init__(self, _type: Any):
        self.__type = _type
        self.__value = None
        self.__name = None

    def __get__(self, instance: Any, owner: Any) -> Any:
        return self.__value

    def __set__(self, instance: Any, value: Any):
        Util.is_type(value, self.__type)
        self.__value = value

    def __delete__(self, instance: Any):
        raise ValueError("Can not delete handle for %s" % self.__name)

    def __set_name__(self, owner: Any, name: str):
        self.__name = name


class StaticHandle(Handle):
    """
    The static handle works the same way as the Handle, except it can only be
    set once.
    """

    def __set__(self, instance: Any, value: Any):
        if self.__value:
            raise ValueError(  # noqa E701
                "Handle already set for %s" % self.__name
            )
        Util.is_type(value, self.__type)
        self.__value = value
