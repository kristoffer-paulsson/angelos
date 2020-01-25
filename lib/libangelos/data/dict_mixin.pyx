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
from typing import Any

from libangelos.misc import Loop, Misc
from libangelos.reactive import ObserverMixin, NotifierMixin


class ReactiveValue(NotifierMixin):
    """
    A class holding a value that can be subscribed to.
    """
    def __init__(self, value: Any = None):
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
            self.__items[key] = ReactiveValue(Misc.from_ini(value))

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

        return Misc.from_ini(self.__items[item].value)

    def __setitem__(self, key: str, value: Any) -> None:
        value = Misc.to_ini(value)
        if key not in self.__items.keys():
            self.__items[key] = ReactiveValue(value)

        item = self.__items[key]
        item.value = value
        self.facade.api.settings.set(self.SECTION[0], key, value)

        item.notify_all(1, {"attr": key, "value": value})
        Loop.main().run(self.facade.api.settings.save_preferences())

    def __delitem__(self, key: str) -> None:
        pass