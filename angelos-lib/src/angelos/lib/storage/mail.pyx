# cython: language_level=3, linetrace=True
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
"""Vault."""
import uuid
from pathlib import PurePosixPath
from typing import List

from angelos.lib.const import Const
from angelos.lib.policy.portfolio import PortfolioPolicy

from angelos.lib.helper import Glue, Globber
from angelos.lib.storage.storage import StorageFacadeExtension


class MailStorage(StorageFacadeExtension):
    """
    Mail box interface.

    Mail is the archive that is used to store messages on the
    server. Clients will push and pull their messages to the server for routing
    within the community.
    """
    ATTRIBUTE = ("mail",)

    CONCEAL = (Const.CNL_MAIL,)
    USEFLAG = (Const.A_USE_MAIL,)

    INIT_HIERARCHY = ()

    async def save(self, filename: PurePosixPath, document, document_file_id_match=True):
        """Save a document at a certain location.

        Args:
            filename:
            document:
            document_file_id_match:

        Returns:

        """
        created, updated, owner = Glue.doc_save(document)

        if document_file_id_match:
            file_id = document.id
        else:
            file_id = uuid.uuid4()

        return await self.archive.mkfile(
            filename=filename,
            data=PortfolioPolicy.serialize(document),
            id=file_id,
            owner=owner,
            created=created,
            modified=updated,
        )
    async def delete(self, filename: PurePosixPath):
        """Remove a document at a certain location."""
        return await self.archive.remove(filename)

    async def update(self, filename: PurePosixPath, document):
        """Update a document on file."""
        created, updated, owner = Glue.doc_save(document)

        return await self.archive.save(
            filename=filename,
            data=PortfolioPolicy.serialize(document),
            modified=updated,
        )

    async def issuer(self, issuer, path: PurePosixPath = PurePosixPath("/"), limit=1):
        """Search a folder for documents by issuer."""
        raise DeprecationWarning('Use "search" instead of "issuer".')

        result = await Globber.owner(self.archive, issuer, path)
        result.sort(reverse=True, key=lambda e: e[2])

        datalist = []
        for r in result[:limit]:
            datalist.append(self._archive.load(r[0]))

        return datalist

    async def search(
        self, issuer: uuid.UUID = None, path: PurePosixPath = PurePosixPath("/"), limit: int = 1
    ) -> List[bytes]:
        """Search a folder for documents by issuer and path."""

        if issuer:
            result = await Globber.owner(self.archive, issuer, path)
        else:
            result = await Globber.path(self.archive, path)

        result.sort(reverse=True, key=lambda e: e[2])

        datalist = []
        for r in result[:limit]:
            datalist.append(await self.archive.load(r[0]))

        return datalist
