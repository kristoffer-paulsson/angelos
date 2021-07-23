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
import datetime
import functools
import uuid
from pathlib import PurePosixPath
from typing import Optional, Callable, Dict, Any

from angelos.archive7.archive import Archive7, TYPE_FILE, TYPE_LINK
from angelos.facade.facade import StorageFacadeExtension
from angelos.lib.const import Const
from angelos.lib.helper import Glue, Globber
from angelos.document.utils import Helper as DocumentHelper


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

    async def receive_iter(self, owner: uuid.UUID):
        """Iterator that iterates over files belonging to an owner."""
        async for entry, path in self.archive.search(query=Archive7.Query().type(TYPE_FILE).owner(owner)):
            yield entry, path

    async def save(self, filename: PurePosixPath, document, document_file_id_match=True) -> uuid.UUID:
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
            data=DocumentHelper.serialize(document),
            id=file_id,
            owner=owner,
            created=created,
            modified=updated
        )

    async def delete(self, filename: PurePosixPath):
        """Remove a document at a certain location.

        Args:
            filename:

        Returns:

        """
        await self.archive.remove(filename)

    async def update(self, filename: PurePosixPath, document) -> uuid.UUID:
        """Update a document on file.

        Args:
            filename:
            document:

        Returns:

        """
        created, updated, owner = Glue.doc_save(document)

        return await self.archive.save(
            filename=filename,
            data=DocumentHelper.serialize(document),
            modified=updated,
        )

    async def issuer(self, issuer, path: PurePosixPath = PurePosixPath("/"), limit=1):
        """Search a folder for documents by issuer."""
        raise DeprecationWarning('Use "search" instead of "issuer".')

        result = await Globber.owner(self.archive, issuer, path)
        result.sort(reverse=True, key=lambda e: e[2])

        datalist = []
        for r in result[:limit]:
            datalist.append(await self.archive.load(r[0]))

        return datalist

    async def search(
        self, pattern: str = "/", modified: datetime.datetime = None, created: datetime.datetime = None,
        owner: uuid.UUID = None, link: bool = False, limit: int = 0, deleted: Optional[bool] = None,
        fields: Callable = lambda name, entry: name
    ) -> Dict[uuid.UUID, Any]:
        """Searches for a files in the storage.

        Args:
            pattern (str):
                Path search pattern.
            modified (datetime.datetime):
                Files modified since.
            created (datetime.datetime):
                Files created since.
            owner (uuid.UUID):
                Files belonging to owner.
            link (bool):
                Include links in result.
            limit (int):
                Max number of hits (0 is unlimited).
            deleted (bool):
                Search for deleted files.
            fields (lambda):
                Lambda function that compiles the result row.

        Returns (Dict[uuid.UUID, Any]):
            Returns a dictionary with a custom resultset indexed by file ID.

        """
        sq = Archive7.Query(pattern=pattern)
        sq.type((TYPE_FILE, TYPE_LINK) if link else TYPE_FILE).deleted(deleted)
        if modified:
            sq.modified(modified)
        if created:
            sq.created(created)
        if owner:
            sq.owner(owner)

        result = dict()
        count = 0
        async for entry, path in self.archive.search(sq):
            if link and entry.type == TYPE_LINK:
                followed = self.archive._Archive7__manager._FileSystemStreamManager__follow_link(entry.id)
                result[entry.id] = fields(path, followed)
            else:
                result[entry.id] = fields(path, entry)

            count += 1
            if count == limit:
                break

        return result
