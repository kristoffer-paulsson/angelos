# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade settings API."""
import uuid
import io
import csv
from configparser import ConfigParser, ExtendedInterpolation
from typing import Set, Tuple

from ..policy import PrivatePortfolio
from ..archive.vault import Vault


class SettingsAPI:
    """An interface class to be placed on the facade."""

    def __init__(self, portfolio: PrivatePortfolio, vault: Vault):
        """Init settings interface."""
        self.__portfolio = portfolio
        self.__vault = vault

    async def __load(self, name: str) -> io.StringIO:
        return io.StringIO((await self.__vault.load_settings(name)).decode())

    async def __save(self, name: str, text: io.StringIO):
        return await self.__vault.save_settings(name, text.getvalue().encode())

    async def preferences(self) -> ConfigParser:
        """Load all available networks."""
        parser = ConfigParser(interpolation=ExtendedInterpolation())
        parser.read_file(await self.__load("preferences.ini"))
        return parser

    async def save_prefs(self, parser: ConfigParser) -> bool:
        """Load all available networks."""
        text = io.StringIO()
        parser.write(text)
        return await self.__save("preferences.ini", text)

    async def networks(self) -> Set[Tuple[uuid.UUID, bool]]:
        """Load all available networks."""
        nets = set()
        for row in csv.reader(await self.__load("networks.csv")):
            nets.add(tuple(row))
        return nets
