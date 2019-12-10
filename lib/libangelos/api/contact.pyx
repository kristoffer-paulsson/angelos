# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Facade mail API."""
from typing import List

from libangelos.api.api import ApiFacadeExtension
from libangelos.document.entities import Person, Ministry, Church
from libangelos.document.types import EntityT
from libangelos.facade.base import BaseFacade
from libangelos.helper import Glue
from libangelos.utils import LazyAttribute


class ContactAPI(ApiFacadeExtension):
    """ContactAPI is an interface class, placed on the facade."""

    ATTRIBUTE = ("contact",)

    PORTFOLIOS = "/portfolios"

    def __init__(self, facade: BaseFacade):
        """Initialize the Contacts."""
        ApiFacadeExtension.__init__(self, facade)
        self.__vault = LazyAttribute(lambda: self.facade.storage.vault)
        self.__portfolio = LazyAttribute(lambda: self.facade.data.portfolio)

    async def load_all(self) -> List[EntityT]:
        """Load contacts from portfolios."""
        doc_list = await self.__vault.search(
            path=ContactAPI.PORTFOLIOS + "/*/*.ent",
            limit=1000
        )
        result = Glue.doc_validate_report(doc_list, (Person, Ministry, Church))
        return result
