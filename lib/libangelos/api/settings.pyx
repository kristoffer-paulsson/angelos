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
from configparser import ConfigParser, ExtendedInterpolation
from typing import Set, Tuple

from libangelos.api.api import ApiFacadeExtension
from libangelos.facade.base import BaseFacade
from libangelos.utils import LazyAttribute


class SettingsAPI(ApiFacadeExtension):
    """An interface class to be placed on the facade."""

    ATTRIBUTE = ("settings",)

    def __init__(self, facade: BaseFacade):
        """Initialize the Mail."""
        ApiFacadeExtension.__init__(self, facade)
        self.__vault = LazyAttribute(lambda: self.facade.storage.vault)
        self.__portfolio = LazyAttribute(lambda: self.facade.data.portfolio)

    async def __load(self, name: str) -> io.StringIO:
        return io.StringIO((await self.__vault.load_settings(name)).decode())

    async def __save(self, name: str, text: io.StringIO) -> bool:
        return await self.__vault.save_settings(name, text.getvalue().encode())

    async def load_preferences(self) -> ConfigParser:
        """
        Load all available networks.

        :return:
        """
        parser = ConfigParser(interpolation=ExtendedInterpolation())
        parser.read_file(await self.__load("preferences.ini"))
        return parser

    async def save_preferences(self, parser: ConfigParser) -> bool:
        """
        Load all available networks.

        :param parser:
        :return:
        """
        text = io.StringIO()
        parser.write(text)
        return await self.__save("preferences.ini", text)

    async def networks(self) -> Set[Tuple[uuid.UUID, bool]]:
        """
        Load all available networks

        :return:
        """
        nets = set()
        for row in csv.reader(await self.__load("networks.csv")):
            nets.add(tuple(row))
        return nets
