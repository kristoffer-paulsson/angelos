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
"""Facade settings API."""
import csv
import io
import uuid
from configparser import ConfigParser
from typing import Set, Tuple, Any

from angelos.facade.facade import ApiFacadeExtension, Facade
from angelos.common.misc import Misc

# TODO: Re-implement settings using DataFacadeExtension


class SettingsAPI(ApiFacadeExtension):
    """An interface class to be placed on the facade."""

    ATTRIBUTE = ("settings",)
    PATH_PREFS = ("preferences.ini",)

    add_section = None
    options = None
    sections = None
    items = None
    get = None
    set = None

    def __init__(self, facade: Facade):
        """Initialize the Mail."""
        ApiFacadeExtension.__init__(self, facade)
        self.__config = ConfigParser()
        self.__config.optionxform = str
        self.add_section = self.__config.add_section
        self.options = self.__config.options
        self.sections = self.__config.sections
        self.items = self.__config.items
        self.get = self.__config.get
        self.set = self.__config.set

    async def load_preferences(self) -> None:
        """
        Load preferences.ini file into a configparser.
        """
        self.__config.read_file(await self.facade.storage.vault.load_settings(self.PATH_PREFS[0]))

    async def save_preferences(self) -> bool:
        """
        Save a configparser into preferences.ini file.
        """
        text = io.StringIO()
        self.__config.write(text)
        return await self.facade.storage.vault.save_settings(self.PATH_PREFS[0], text)

    async def load_set(self, name: str) -> Set[Tuple[Any, ...]]:
        """
        Load a csv file into a set of tuples.

        Args:
            name: filename

        Returns:
            Set of tupled data.
        """
        data = set()
        for row in csv.reader(await self.facade.storage.vault.load_settings(name)):
            if not row[0].startswith("#"):
                data.add(tuple([Misc.from_ini(value) for value in row]))
        return data

    async def save_set(self, name: str, data: Set[Tuple[Any, ...]]) -> bool:
        """
        Save a set of tuples as rows in a csv file.

        Args:
            name: filename
            data: set of tuples

        Returns:
            Success of failure
        """
        output = io.StringIO()
        writer  = csv.writer(output)
        for row in data:
            writer.writerow([Misc.to_ini(value) for value in row])
        return await self.facade.storage.vault.save_settings(name, output)

    async def networks(self) -> Set[Tuple[uuid.UUID, bool]]:
        """
        Load all available networks.

        Returns:
            set of tuples width network UUID's
        """
        return await self.load_set("networks.csv")
