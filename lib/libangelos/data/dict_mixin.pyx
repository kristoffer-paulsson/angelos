# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""A reactive dictionary mixin

Exposes ConfigApi section as a dictionary on the data API.
All items are reactive and can be subscribed to.
"""
import asyncio
from typing import Any

from libangelos.reactive import ObserverMixin, NotifierMixin


class ReactiveValue(NotifierMixin):
    """
    A class holding a value that can be subscribed to.
    """
    def __init__(self, value: Any=None):
        NotifierMixin.__init__(self)
        self.value = value


class DictionaryMixin:
    """
    A Mixin that allows a FacadeDataExtension to expose preferences values
    that are reactive.
    """
    SECTION = ("",)

    def __init__(self):
        self.__items = dict()

    def post_init(self) -> None:
        """Loads a preferences section from the settings api"""
        settings = self.facade.api.settings
        sections = settings.sections()
        if self.SECTION[0] not in sections:
            settings.add_section(self.SECTION[0])

        for key, value in settings.items(self.SECTION[0]):
            self.__items[key] = ReactiveValue(self.from_ini(value))

    def subscribe(self, option: str, observer: ObserverMixin) -> None:
        """Adds a subscriber to said option.

        Args:
            option (str):
                Option name to subscribe to.
            observer (ObserverMixin):
                The subscriber class.

        """
        if option not in self.__items.keys():
            self.__items[option] = ReactiveValue()

        self.__items[option].subscribe(observer)

    def unsubscribe(self, option: str, observer: ObserverMixin) -> None:
        """Removes subscriber from said option.

        Args:
            option (str):
                Option name to subscribe to.
            observer (ObserverMixin):
                The subscriber class.

        """
        if option in self.__items.keys():
            self.__items[option] = ReactiveValue()

        self.__items[option].unsubscribe(observer)

    def __getitem__(self, item: str) -> Any:
        if item not in self.__items.keys():
            raise KeyError(item)

        return self.__items[item].value

    def __setitem__(self, key: str, value: Any) -> None:
        if key not in self.__items.keys():
            self.__items[key] = ReactiveValue(value)

        item = self.__items[key]
        item.value = value
        self.facade.api.settings.set(self.SECTION[0], key, self.to_ini(value))

        item.notify_all(1, {"attr": key, "value": value})
        asyncio.ensure_future(self.facade.api.settings.save_preferences())

    def __delitem__(self, key: str) -> None:
        pass

    def to_ini(self, value: Any) -> str:
        """Convert python value to INI string.

        Args:
            value (Any):
                Value to stringify.
        Returns(str):
            INI string.

        """
        if type(value) in (bool, type(None)):
            return str(value).lower()
        else:
            return str(value)

    def from_ini(self, value: str) -> Any:
        """Convert INI string to python value.

        Args:
            value (str):
                INI string to pythonize.
        Returns (Any):
            Python value.

        """
        if is_int(value):
            return int(value)
        elif is_float(value):
            return float(value)
        elif is_bool(value):
            return to_bool(value)
        elif is_none(value):
            return None
        else:
            return value


# ATTRIBUTION
#
# The following section is copied from the "localconfig" project:
# https://github.com/maxzheng/localconfig.git
# Copyright (c) 2014 maxzheng
# Licensed under the MIT license

def is_float(value):
    """Checks if the value is a float """
    return _is_type(value, float)

def is_int(value):
    """Checks if the value is an int """
    return _is_type(value, int)

def is_bool(value):
    """Checks if the value is a bool """
    return value.lower() in ['true', 'false', 'yes', 'no', 'on', 'off']

def is_none(value):
    """Checks if the value is a None """
    return value.lower() == str(None).lower()

def to_bool(value):
    """Converts value to a bool """
    return value.lower() in ['true', 'yes', 'on']

def _is_type(value, t):
    try:
        t(value)
        return True
    except Exception:
        return False