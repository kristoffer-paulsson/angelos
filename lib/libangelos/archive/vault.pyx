# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Vault."""
import logging
import uuid
import io
from typing import List

from libangelos.archive.portfolio_mixin import PortfolioMixin
from libangelos.archive.storage import StorageFacadeExtension
from libangelos.archive7 import Entry
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
        "/contacts/friend",
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
        ("/settings/preferences.ini", b""),
        ("/settings/networks.csv", b"")
    )

    NODES = "/settings/nodes"
    INBOX = "/messages/inbox/"

    @classmethod
    def setup(
            cls,
            home_dir: str,
            secret: bytes,
            portfolio: PrivatePortfolio,
            vtype=None,
            vrole=None,
    ) -> object:
        """Create and setup the whole Vault according to policy's."""
        return super(VaultStorage, cls).setup(
            None,
            home_dir,
            secret,
            owner=portfolio.entity.id,
            node=next(iter(portfolio.nodes)).id,
            domain=portfolio.domain.id,
            vtype=vtype,
            vrole=vrole
        )

    async def save(self, filename, document):
        """Save a document at a certain location."""
        created, updated, owner = Glue.doc_save(document)

        return await self.proxy.call(
            self.archive.mkfile,
            filename=filename,
            data=PortfolioPolicy.serialize(document),
            id=document.id,
            owner=owner,
            created=created,
            modified=updated,
            compression=Entry.COMP_NONE,
        )

    async def delete(self, filename):
        """Remove a document at a certain location."""
        return await self.proxy.call(self.archive.remove, filename=filename)

    async def update(self, filename, document):
        """Update a document on file."""
        created, updated, owner = Glue.doc_save(document)

        return await self.proxy.call(
            self.archive.save,
            filename=filename,
            data=PortfolioPolicy.serialize(document),
            modified=updated,
        )

    async def issuer(self, issuer, path="/", limit=1):
        """Search a folder for documents by issuer."""
        raise DeprecationWarning('Use "search" instead of "issuer".')

        def callback():
            result = Globber.owner(self.archive, issuer, path)
            result.sort(reverse=True, key=lambda e: e[2])

            datalist = []
            for r in result[:limit]:
                datalist.append(self.archive.load(r[0]))

            return datalist

        return await self.proxy.call(callback, 0, 5)

    async def search(
            self, issuer: uuid.UUID = None, path: str = "/", limit: int = 1
    ) -> List[bytes]:
        """Search a folder for documents by issuer and path."""

        def callback():
            if issuer:
                result = Globber.owner(self.archive, issuer, path)
            else:
                result = Globber.path(self.archive, path)

            result.sort(reverse=True, key=lambda e: e[2])

            datalist = []
            for r in result[:limit]:
                datalist.append(self.archive.load(r[0]))

            return datalist

        return await self.proxy.call(callback, 0, 5)

    async def save_settings(self, name: str, text: io.StringIO) -> bool:
        """Save or update a text settings file."""
        try:
            filename = "/settings/" + name
            if self.archive.isfile(filename):
                method = self.archive.save
            else:
                method = self.archive.mkfile

            return await self.proxy.call(
                method,
                filename=filename,
                data=text.getvalue().encode(),
                owner=self.facade.data.portfolio.entity.id,
            )
        except Exception as e:
            logging.exception(e)

        return False

    async def load_settings(self, name: str) -> io.StringIO:
        """Load a text settings file."""
        filename = "/settings/" + name
        if self.archive.isfile(filename):
            data = await self.proxy.call(
                self.archive.load,
                filename=filename
            )
            return io.StringIO(data.decode())
        return io.StringIO()
