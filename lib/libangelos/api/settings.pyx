# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Facade settings API.

@todo Re-implement settings using DataFacadeExtension
"""
import csv
import io
import uuid
from configparser import ConfigParser
from typing import Set, Tuple, Any

from libangelos.api.api import ApiFacadeExtension
from libangelos.facade.base import BaseFacade


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

    def __init__(self, facade: BaseFacade):
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
            data.add(tuple(row))
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
            writer.writerow(row)
        output.close()
        return await self.facade.storage.vault.save_settings(name, output)

    async def networks(self) -> Set[Tuple[uuid.UUID, bool]]:
        """
        Load all available networks.

        Returns:
            set of tuples width network UUID's
        """
        return await self.load_set("network.csv")