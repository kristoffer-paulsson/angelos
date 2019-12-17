# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Utility module.

The utility module containse all minor extras that is used globally in the
application.
"""
import asyncio
import importlib
import os
import sys
from typing import _GenericAlias

from libangelos.error import ERROR_INFO


class Event(asyncio.Event):
    """A threadsafe asynchronous event class."""

    def set(self):
        self._loop.call_soon_threadsafe(super().set)


class Util:
    """@todo."""

    __app_path = os.path.dirname(os.path.abspath(sys.argv[0]))
    __usr_path = os.path.expanduser("~")
    __exe_path = os.path.abspath(os.getcwd())

    @staticmethod
    def app_dir():
        """Absolute path to the executed scripts location."""
        return Util.__app_path

    @staticmethod
    def usr_dir():
        """Absolute path to user home directory."""
        return Util.__usr_path

    @staticmethod
    def exe_dir():
        """Absolute path to current working directory."""
        return Util.__exe_path

    @staticmethod
    def path(dirname, filename):
        """Merge directory path and filename."""
        return os.path.join(dirname, filename)

    @staticmethod
    def is_type(instance, types):
        """
        check_type is a helper function. Tests for an instance and raises a
        standardized TypeError exception.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them

        Example:
        check_type(result, (NoneType, StringType))
        """
        if not isinstance(instance, types):
            raise TypeError(
                "Instance expected type {0}, but got: {1}".format(
                    str(types), str(instance)
                )
            )

    @staticmethod
    def is_class(instance, types):
        """
        check_class is a helper function. Tests for a subclass and raises a
        standardized TypeError exception.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them

        Example:
        check_class(result, (Model, BaseModel))
        """
        if not issubclass(instance, types):
            raise TypeError(
                "Subclass expected type {0}, but got: {1}".format(
                    str(types), str(instance)
                )
            )

    def is_typing(instance, types):
        """
        Check instance, even on typing classes.

        Instance    The instanced variable
        type        The class type of expected type, or tuple of them
        """
        if isinstance(types, _GenericAlias):
            return isinstance(instance, types.__args__)
        else:
            return isinstance(instance, types)

    @staticmethod
    def is_path(instance):
        """
        check_path is a helper function. Tests for a PathLike and raises a
        standardized TypeError exception.

        Instance    The instanced variable

        Example:
        check_class(result, (Model, BaseModel))
        """
        if not isinstance(instance, os.PathLike):
            raise TypeError(
                "Path like object expected, but got: {0}".format(str(instance))
            )

    @staticmethod
    def populate(klass: object, attributes: dict) -> None:
        """
        Populate class attributes from dictionary.

        Args:
            klass:
            attributes:
        """
        for attr, value in attributes.items():
            if hasattr(klass, attr):
                setattr(klass, attr, value)

    @staticmethod
    def exception(error_code, debug_info={}):
        """Docstring"""
        Util.is_type(error_code, int)
        Util.is_type(debug_info, dict)

        debug = []
        if debug_info:
            for k in debug_info:
                debug.append("{k}: {i}".format(k=k, i=debug_info[k]))
                debug_text = ": [{data}]".format(data=", ".join(debug))
        else:
            debug_text = "."
        return ERROR_INFO[error_code][0](
            "{msg}{debug}".format(
                msg=ERROR_INFO[error_code][1], debug=debug_text
            )
        )

    @staticmethod
    def format_exception(
        exception_type, instance, message="Formated exception", debug_info={}
    ):
        """
        format_exception is a helper function. It will populate and format an
        exception so that it is understandable and include good debug data.

        exception_type  Requiers an exception type
        instance        The class name of current class, or the current
                        instance itself
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
        Util.is_class(exception_type, Exception)
        Util.is_type(instance, (object, str))
        Util.is_type(message, str)
        Util.is_type(debug_info, dict)

        debug = []
        for k in debug_info:
            debug.append("{0}: {1}".format(k, debug_info[k]))
        if isinstance(instance, object):
            name = instance.__class__.__name__
        else:
            name = instance
        exc = exception_type(
            '{0}, "{1}" - debug: {2}'.format(name, message, ", ".join(debug))
        )
        return exc

    @staticmethod
    def format_info(event_str, data=None):
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
        Util.is_type(event_str, str)
        Util.is_type(data, (dict, type(None)))

        if not data:
            return "{0}.".format(event_str)
        else:
            info = []
            for k in data:
                info.append("{0}: {1}".format(k, data[k]))
            return "{0}. Info: ({1})".format(event_str, ", ".join(info))

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
        Util.is_type(caught_exception, Exception)
        Util.is_type(event_str, str)

        return "{0}, Class: {1}:{2}".format(
            event_str, str(type(caught_exception)), caught_exception
        )

    @staticmethod
    def imp_pkg(path):
        """
        imp_pkg is a helper function for importing classes dynamically by
        telling the search path
        path        String that tells where to find the class
        return        Returns a class descriptor

        Example:
        klass = Util.imp_pkg('module.package.Class')
        c_instance = klass()
        """
        Util.is_type(path, str)
        pkg = path.rsplit(".", 1)
        return getattr(importlib.import_module(pkg[0]), pkg[1])

    @staticmethod
    def class_pkg(klass):
        """Docstring"""
        return "{0}.{1}".format(
            klass.__class__.__module__, klass.__class__.__name__
        )

    @staticmethod
    def hours(seconds):
        """Docstring"""
        if seconds > 24 * 3600:
            return "{:>7.2}d".format(float(seconds / (24 * 3600)))
        else:
            seconds = int(seconds)
            hour = int(seconds / 3600)
            mins = int(seconds / 60)
            secs = seconds - hour * 3600 - mins * 60
            return "{:}:{:02}:{:02}".format(hour, mins, secs)


class FactoryInterface:
    """Docstring"""

    @classmethod
    def factory(cls, **kwargs):
        """Docstring"""
        return cls(kwargs["io"])


