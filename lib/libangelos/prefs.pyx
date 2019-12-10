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
import collections


class Preferences(collections.MutableMapping):
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
    def __init__(self, facade, fields={}):
        self.__facade = facade
        self.__parser = None
        self.__fields = fields

    async def load(self):
        self.__parser = await self.__facade.settings.load_preferences()
        print(self.__parser)

    async def save(self):
        return await self.__facade.settings.save_preferences(self.__parser)

    # @property
    # def network(self):
    #    return self.__parser.get(
    #       "Preferences", "CurrentNetwork", fallback=None)

    # @network.setter
    # def network(self, value):
    #    self.__parser.set("Preferences", "CurrentNetwork", value)

    def __getitem__(self, key: str) -> str:
        if key in self.__dict__:
            return self.__dict__[key]
        elif key.startswith("free_"):
            return self.__parser.get("Free", key, fallback=None)
        elif key in self.__fields:
            return self.__parser.get(
                self.__fields[key][0],
                self.__fields[key][1],
                self.__fields[key][2]
            )
        else:
            raise KeyError()

    def __setitem__(self, key, value):
        if key in self.__dict__:
            self.__dict__[key] = value
        elif key.startswith("free_"):
            self.__parser.set("Free", key, value)
        elif key in self.__fields:
            self.__parser.set(
                self.__fields[key][0],
                self.__fields[key][1],
                value
            )
        else:
            raise KeyError()

    def __delitem__(self, key):
        pass

    def __iter__(self):
        pass

    def __len__(self):
        pass

    def __repr__(self):
        return ""
