# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Facade mail API."""
from typing import List

from ..policy.portfolio import PrivatePortfolio
from ..document._types import EntityT
from ..document.entities import Person, Ministry, Church
from ..archive.vault import Vault
from ..archive.helper import Glue


class ContactAPI:
    """ContactAPI is an interface class, placed on the facade."""

    PORTFOLIOS = "/portfolios"

    def __init__(self, portfolio: PrivatePortfolio, vault: Vault):
        """Init contact interface."""
        self.__portfolio = portfolio
        self.__vault = vault

    async def load_all(self) -> List[EntityT]:
        """Load contacts from portfolios."""
        doclist = await self.__vault.search(
            path=ContactAPI.PORTFOLIOS + "/*/*.ent",
            limit=1000
        )
        result = Glue.doc_validate_report(doclist, (Person, Ministry, Church))
        return result
