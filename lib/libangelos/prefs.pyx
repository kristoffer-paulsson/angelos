# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Preferences classes and functions that are saved in vault.ar7.cnl.
/settings/preferences.ini
"""


class Preferences:
    """Loads, saves and serves preferences from the vault.

    The preferences that are of special significance is programmed via a
    dictionary of sets with information. Example:

    {
        "attribute": ("<Section>", "Setting", "<default>"),
        "network": ("Preferences", "CurrentNetwork", None),
    }

    It is alse possible to save and load preferences without signifiance in the
    free namespace. The section name is "Free" and are accessed via the
    prefs.free_* attributes.

    Parameters
    ----------
    facade : Facade
        Facade to load the vault from.
    fields : dict
        Dictionary of predefined settings.
    """
    def __init__(self, facade, fields):
        self._facade = facade
        self._parser = None
        self.__fields = fields

    async def load(self):
        self._parser = await self._facade.settings.preferences()

    async def save(self):
        return await self._facade.settings.save_prefs(self._parser)

    # @property
    # def network(self):
    #    return self._parser.get(
    #       "Preferences", "CurrentNetwork", fallback=None)

    # @network.setter
    # def network(self, value):
    #    self._parser.set("Preferences", "CurrentNetwork", value)

    def __getattr__(self, name: str) -> str:
        if name.startswith("free_"):
            return self._parser.get("Free", name, fallback=None)
        elif name in self.__fields.keys():
            return self._parser.get(
                self.__fields[name][0],
                self.__fields[name][1],
                self.__fields[name][2]
            )
        else:
            raise AttributeError()

    def __setattr__(self, name: str, value: str):
        if name.startswith("free_"):
            self._parser.set("Free", name, value)
        elif name in self.__fields.keys():
            self._parser.set(
                self.__fields[name][0],
                self.__fields[name][1],
                value
            )
        else:
            raise AttributeError()
