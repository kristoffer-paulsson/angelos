# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade settings API."""
import uuid
import io
import csv
from typing import Set, Tuple

from ..policy import PrivatePortfolio
from ..archive.vault import Vault


class SettingsAPI:
    """An interface class to be placed on the facade."""

    def __init__(self, portfolio: PrivatePortfolio, vault: Vault):
        """Init settings interface."""
        self.__portfolio = portfolio
        self.__vault = vault

    async def networks(self) -> Set[Tuple[uuid.UUID, bool]]:
        """Load all available networks."""
        nets = set()
        data = io.StringIO(
            (await self.__vault.load_settings('networks.csv')).decode())

        for row in csv.reader(data):
            nets.add(tuple(row))

        return nets
