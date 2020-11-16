# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""A reactive dictionary mixin

Exposes ConfigApi section as a dictionary on the data API.
All items are reactive and can be subscribed to.
"""
from typing import Any

from angelos.common.misc import Loop, Misc
from angelos.lib.reactive import ObserverMixin, NotifierMixin


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
        self._settings = self.facade.api.settings

        sections = self._settings.sections()
        if self.SECTION[0] not in sections:
            self._settings.add_section(self.SECTION[0])

        for key, value in self._settings.items(self.SECTION[0]):
            self.__items[key] = ReactiveValue(value)

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
        self._settings.set(self.SECTION[0], key, value)

        item.notify_all(1, {"attr": key, "value": value})
        Loop.main().run(self._settings.save_preferences())

    def __delitem__(self, key: str) -> None:
        pass