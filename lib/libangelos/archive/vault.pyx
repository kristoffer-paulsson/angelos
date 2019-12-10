# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Vault."""
import asyncio
import uuid
import logging
from typing import List

from .portfolio_mixin import PortfolioMixin
from ..const import Const
from ..policy.portfolio import (
    Portfolio,
    PrivatePortfolio,
    PField,
    DOCUMENT_PATH,
    PORTFOLIO_PATTERN,
    PortfolioPolicy,
)
from ..archive7 import Entry
from ..helper import Glue, Globber
from .storage import StorageFacadeExtension


class VaultStorage(StorageFacadeExtension, PortfolioMixin):
    """
    Vault interface.

    The Vault is the most important archive in a facade, because it contains
    the private entity data.
    """

    ATTRIBUTE = ("vault",)
    CONCEAL = (Const.CNL_VAULT,)
    USEFLAG = (Const.A_USE_VAULT,)

    HIERARCHY = (
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

    async def save_settings(self, name: str, data: bytes) -> bool:
        """Save or update a settings file."""
        try:
            filename = "/settings/" + name
            if self.archive.isfile(filename):
                self.archive.save(filename, data)
            else:
                self.archive.mkfile(filename, data)
        except Exception as e:
            logging.exception(e)
            return False

        return True

    async def load_settings(self, name: str) -> bytes:
        """Load a settings file."""
        filename = "/settings/" + name
        if self.archive.isfile(filename):
            return self.archive.load(filename)
        return b""
