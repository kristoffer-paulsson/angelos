# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Vault."""
import datetime
import io
import logging
import uuid
from typing import List, Dict, Any, Optional

from libangelos.storage.portfolio_mixin import PortfolioMixin
from libangelos.storage.storage import StorageFacadeExtension
from archive7 import EntryRecord, Archive7
from libangelos.const import Const
from libangelos.helper import Glue, Globber
from libangelos.policy.portfolio import PrivatePortfolio, PortfolioPolicy


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
        "/",
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
        # Messages, ingoing and outgoung correspondence
        "/messages",
        "/messages/inbox",
        "/messages/read",
        "/messages/drafts",
        "/messages/outbox",
        "/messages/sent",
        "/messages/spam",
        "/messages/trash",
        # Networks, for other hosts that are trusted
        "/networks"
        # Preferences by the owning entity.
        "/settings",
        "/settings/nodes",
        "/portfolios",
    )

    INIT_FILES = (
        ("/settings/preferences.ini", b"# Empty"),
        ("/settings/networks.csv", b"# Empty")
    )

    NODES = "/settings/nodes"
    INBOX = "/messages/inbox/"

    @classmethod
    async def setup(cls, home_dir: str, secret: bytes, portfolio: PrivatePortfolio, vtype=None, vrole=None) -> object:
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
            vtype=vtype,
            vrole=vrole
        )

    async def save(self, filename, document, document_file_id_match=True):
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
            compression=Entry.COMP_NONE
        )

    async def delete(self, filename: str):
        """Remove a document at a certain location.

        Args:
            filename:

        Returns:

        """
        return await self.archive.remove(filename)

    async def link(self, path: str, link_to: str) -> None:
        """Create a link to file or directory.

        Args:
            path (str):
                Path of the link.
            link_to (str:
                Path being linked to.

        """
        await self.archive.link(path, link_to)

    async def update(self, filename, document):
        """Update a document on file.

        Args:
            filename:
            document:

        Returns:

        """
        created, updated, owner = Glue.doc_save(document)

        return await self.archive.save(
            filename=filename,
            data=PortfolioPolicy.serialize(document),
            modified=updated,
        )

    async def issuer(self, issuer, path="/", limit=1):
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
            fields = lambda name, entry: name
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
        try:
            def query(q):
                """

                Args:
                    q:

                Returns:

                """
                q.type((b"f", b"l") if link else b"f").deleted(deleted)
                if modified:
                    q.modified(modified)
                if created:
                    q.created(created)
                if owner:
                    q.owner(owner)
                return q

            return await self.archive.execute(
                self._callback_search,
                pattern,
                query,
                fields,
                limit,
                link
            )
        except Exception as e:
            logging.exception(e)

    def _callback_search(
            self,
            pattern,
            query = lambda q: q.type(b"f"),
            fields = lambda name, entry: name,
            limit = 0,
            follow = False
    ) -> dict:
        """Internal search function that searches for files.

        Note:
            Don't access this method directly. you must use a proxy.

        Args:
            pattern (str):
                Search pattern for the file path.
            query (lambda):
                Lambda function that builds the query after the pattern is set.
            fields (lambda):
                Lambda function that formats each row.

        Returns (dict):
            A dictionary of results indexed by ID.

        """
        idxs = self.archive.ioc.entries.search(query(Archive7.Query(pattern=pattern)))
        ids = self.archive.ioc.hierarchy.ids
        ops = self.archive.ioc.operations

        resultset = dict()
        count = 0
        for _, entry in idxs:
            filename = entry.name.decode()
            if entry.parent.int == 0:
                name = "/" + filename
            else:
                name = ids[entry.parent] + "/" + filename

            if follow and entry.type == Entry.TYPE_LINK:
                link, _ = ops.follow_link(entry)
                resultset[link.id] = fields(name, link)
            else:
                resultset[entry.id] = fields(name, entry)

            count += 1
            if count == limit:
                break

        return resultset

    async def search_docs(
            self, issuer: uuid.UUID = None, path: str = "/", limit: int = 1
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
        filename = "/settings/" + name
        data = text.getvalue().encode()
        if self.archive.isfile(filename):
            return await self.archive.save(filename, data)
        else:
            return await self.archive.mkfile(filename, data, owner=self.facade.data.portfolio.entity.id)

    async def load_settings(self, name: str) -> io.StringIO:
        """Load a text settings file.

        Args:
            name:

        Returns:

        """
        filename = "/settings/" + name
        if self.archive.isfile(filename):
            data = await self.archive.load(filename)
            return io.StringIO(data.decode())
        return io.StringIO()
