# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Vault.
"""
import uuid

from typing import List

from ..policy import PortfolioPolicy
from .archive7 import Entry
from .helper import Glue, Globber
from .archive import BaseArchive


class Mail(BaseArchive):
    """
    Mail box interface.

    Mail is the archive that is used to store messages on the
    server. Clients will push and pull their messages to the server for routing
    within the community.
    """

    HIERARCHY = ("/",)

    async def save(self, filename, document):
        """Save a document at a certian location."""
        created, updated, owner = Glue.doc_save(document)

        return await self._proxy.call(
            self._archive.mkfile,
            filename=filename,
            data=PortfolioPolicy.serialize(document),
            id=document.id,
            owner=owner,
            created=created,
            modified=updated,
            compression=Entry.COMP_NONE,
        )

    async def delete(self, filename):
        """Remove a document at a certian location."""
        return await self._proxy.call(self._archive.remove, filename=filename)

    async def update(self, filename, document):
        """Update a document on file."""
        created, updated, owner = Glue.doc_save(document)

        return await self._proxy.call(
            self._archive.save,
            filename=filename,
            data=PortfolioPolicy.serialize(document),
            modified=updated,
        )

    async def issuer(self, issuer, path="/", limit=1):
        """Search a folder for documents by issuer."""
        raise DeprecationWarning('Use "search" instead of "issuer".')

        def callback():
            result = Globber.owner(self._archive, issuer, path)
            result.sort(reverse=True, key=lambda e: e[2])

            datalist = []
            for r in result[:limit]:
                datalist.append(self._archive.load(r[0]))

            return datalist

        return await self._proxy.call(callback, 0, 5)

    async def search(
        self, issuer: uuid.UUID = None, path: str = "/", limit: int = 1
    ) -> List[bytes]:
        """Search a folder for documents by issuer and path."""

        def callback():
            if issuer:
                result = Globber.owner(self._archive, issuer, path)
            else:
                result = Globber.path(self._archive, path)

            result.sort(reverse=True, key=lambda e: e[2])

            datalist = []
            for r in result[:limit]:
                datalist.append(self._archive.load(r[0]))

            return datalist

        return await self._proxy.call(callback, 0, 5)
