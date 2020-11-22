# cython: language_level=3
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
import io
import uuid
from pathlib import PurePosixPath, Path
from typing import List, Dict, Any, Optional, Callable

from angelos.archive7.archive import TYPE_LINK, Archive7
from angelos.archive7.fs import TYPE_FILE
from angelos.document.utils import Helper as DocumentHelper
from angelos.facade.facade import StorageFacadeExtension
from angelos.facade.storage.portfolio_mixin import PortfolioMixin
from angelos.lib.const import Const
from angelos.lib.helper import Glue, Globber
from angelos.portfolio.collection import PrivatePortfolio


class VaultStorage(StorageFacadeExtension, PortfolioMixin):
    """
    Vault interface.

    The Vault is the most important archive in a facade, because it contains
    the private entity data.
    """

    ATTRIBUTE = ("vault",)
    CONCEAL = (Const.CNL_VAULT,)
    USEFLAG = (Const.A_USE_VAULT,)

    INIT_HIERARCHY = (
        "/cache",
        "/cache/msg",
        # Contact profiles and links based on directory.
        "/contacts",
        "/contacts/favorites",
        "/contacts/friends",
        "/contacts/all",
        "/contacts/blocked",
        # Issued statements by the vaults entity
        "/issued",
        "/issued/verified",
        "/issued/trusted",
        "/issued/revoked",
        # Messages, ingoing and outgoing correspondence
        "/messages",
        "/messages/inbox",
        "/messages/read",
        "/messages/drafts",
        "/messages/outbox",
        "/messages/sent",
        "/messages/spam",
        "/messages/trash",
        # Networks, for other hosts that are trusted
        "/networks",
        # Preferences by the owning entity.
        "/settings",
        "/settings/nodes",
        "/portfolios",
    )

    INIT_FILES = (
        ("/settings/preferences.ini", b""),
        ("/settings/networks.csv", b"")
    )

    NODES = PurePosixPath("/settings/nodes")
    INBOX = PurePosixPath("/messages/inbox")

    @classmethod
    async def setup(
            cls, home_dir: Path, secret: bytes,
            portfolio: PrivatePortfolio, vault_type: int = None, vault_role: int = None
    ) -> object:
        """Create and setup the whole Vault according to policy's.

        Args:
            home_dir (str):
            secret (bytes):
            portfolio (PrivatePortfolio):
            vtype:
            vrole:

        Returns:

        """
        return await super(VaultStorage, cls).setup(
            None,
            home_dir,
            secret,
            owner=portfolio.entity.id,
            node=next(iter(portfolio.nodes)).id,
            domain=portfolio.domain.id,
            vault_type=vault_type,
            vault_role=vault_role
        )

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
        return await self.archive.remove(filename)

    async def link(self, path: PurePosixPath, link_to: PurePosixPath) -> None:
        """Create a link to file or directory.

        Args:
            path (str):
                Path of the link.
            link_to (str:
                Path being linked to.

        """
        await self.archive.link(path, link_to)

    async def update(self, filename: PurePosixPath, document):
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
            self,
            pattern: str = "/",
            modified: datetime.datetime = None,
            created: datetime.datetime = None,
            owner: uuid.UUID = None,
            link: bool = False,
            limit: int = 0,
            deleted: Optional[bool] = None,
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

    async def search_docs(
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

    async def save_settings(self, name: str, text: io.StringIO) -> bool:
        """Save or update a text settings file.

        Args:
            name:
            text:

        Returns:

        """
        filename = PurePosixPath("/settings/", name)
        data = text.getvalue().encode()
        is_file = await self.archive.isfile(filename)
        if is_file:
            return await self.archive.save(filename, data)
        else:
            return await self.archive.mkfile(filename, data, owner=self.facade.data.portfolio.entity.id)

    async def load_settings(self, name: str) -> io.StringIO:
        """Load a text settings file.

        Args:
            name:

        Returns:

        """
        filename = PurePosixPath("/settings/", name)
        is_file = await self.archive.isfile(filename)
        if is_file:
            data = await self.archive.load(filename)
            return io.StringIO(data.decode())
        return io.StringIO()
