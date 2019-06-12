# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Indexing operations for client and server.
"""
from .operation import Operation
from ..facade.facade import Facade
from ..worker import Worker


class Indexer(Operation):
    """Indexing operations."""

    def __init__(self, facade: Facade, worker: Worker):
        """Init indexer class with worker and facade."""
        self.__facade = facade
        self.__worker = worker

    async def contacts_all_index(self):
        """Index all contacts from portfolios."""
        pass

    async def networks_index(self):
        """Index all networks from portfolios."""
        pass
