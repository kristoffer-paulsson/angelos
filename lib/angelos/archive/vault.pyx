# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Vault.
"""
import asyncio
import uuid
import logging
from typing import Tuple, List

import msgpack

from ..policy import (
    Portfolio, PrivatePortfolio, PField, DOCUMENT_PATH, PORTFOLIO_PATTERN,
    PortfolioPolicy)
from .archive7 import Entry
from .helper import Glue, Globber
from .archive import BaseArchive


class Vault(BaseArchive):
    """
    Vault interface.

    The Vault is the most important archive in a facade, because it contains
    the private entity data.
    """

    HIERARCHY = (
        '/',
        '/cache',
        '/cache/msg',
        # Contact profiles and links based on directory.
        '/contacts',
        '/contacts/favorites',
        '/contacts/friend',
        '/contacts/all',
        '/contacts/blocked',
        # Issued statements by the vaults entity
        '/issued',
        '/issued/verified',
        '/issued/trusted',
        '/issued/revoked',
        # Messages, ingoing and outgoung correspondence
        '/messages',
        '/messages/inbox',
        '/messages/read',
        '/messages/drafts',
        '/messages/outbox',
        '/messages/sent',
        '/messages/spam',
        '/messages/trash',
        # Networks, for other hosts that are trusted
        '/networks'
        # Preferences by the owning entity.
        '/settings',
        '/settings/nodes',

        '/portfolios'
    )

    NODES = '/settings/nodes'
    INBOX = '/messages/inbox/'

    async def save(self, filename, document):
        """Save a document at a certian location."""
        created, updated, owner = Glue.doc_save(document)

        return (
            await self._proxy.call(
                self._archive.mkfile, filename=filename,
                data=PortfolioPolicy.serialize(document),
                id=document.id, owner=owner, created=created, modified=updated,
                compression=Entry.COMP_NONE)
            )

    async def delete(self, filename):
        """Remove a document at a certian location."""
        return (
            await self._proxy.call(
                self._archive.remove, filename=filename))

    async def update(self, filename, document):
        """Update a document on file."""
        created, updated, owner = Glue.doc_save(document)

        return (
            await self._proxy.call(
                self._archive.save, filename=filename,
                data=PortfolioPolicy.serialize(document), modified=updated)
            )

    async def issuer(self, issuer, path='/', limit=1):
        """Search a folder for documents by issuer."""
        raise DeprecationWarning('Use "search" instead of "issuer".')

        def callback():
            result = Globber.owner(self._archive, issuer, path)
            result.sort(reverse=True, key=lambda e: e[2])

            datalist = []
            for r in result[:limit]:
                datalist.append(self._archive.load(r[0]))

            return datalist

        return (await self._proxy.call(callback, 0, 5))

    async def search(
            self, issuer: uuid.UUID=None,
            path: str='/', limit: int=1) -> List[bytes]:
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

        return (await self._proxy.call(callback, 0, 5))

    async def new_portfolio(self, portfolio: Portfolio) -> bool:
        """Save a portfolio for the first time."""
        dirname = '/portfolios/{0}'.format(portfolio.entity.id)
        if self._archive.isdir(dirname):
            raise OSError('Portfolio already exists: %s' % portfolio.entity.id)

        self._archive.mkdir(dirname)

        files = []
        issuer, owner = portfolio.to_sets()
        for doc in issuer | owner:
            files.append(
                (DOCUMENT_PATH[doc.type].format(
                    dir=dirname, file=doc.id), doc))

        ops = []
        for doc in files:
            created, updated, owner = Glue.doc_save(doc[1])
            ops.append(self._proxy.call(
                self._archive.mkfile, filename=doc[0],
                data=PortfolioPolicy.serialize(doc[1]),
                id=doc[1].id, created=created, modified=updated, owner=owner,
                compression=Entry.COMP_NONE))

        results = await asyncio.shield(
            asyncio.gather(*ops, return_exceptions=True))
        success = True
        for result in results:
            logging.debug('%s' % result)
            if isinstance(result, Exception):
                success = False
                logging.warning('Failed to save document: %s' % result)
                logging.exception(result)
        return success

    async def load_portfolio(
            self, eid: uuid.UUID, config: Tuple[str]) -> Portfolio:
        """Load portfolio from uuid."""
        dirname = '/portfolios/{0}'.format(eid)
        if not self._archive.isdir(dirname):
            raise OSError('Portfolio doesn\'t exists: %s' % eid)

        result = self._archive.glob(name='{0}/*'.format(dirname), owner=eid)

        files = set()
        for field in config:
            pattern = PORTFOLIO_PATTERN[field]
            for filename in result:
                if pattern == filename[-4:]:
                    files.add(filename)

        ops = []
        for doc in files:
            ops.append(self._proxy.call(
                self._archive.load, filename=doc))

        results = await asyncio.shield(
            asyncio.gather(*ops, return_exceptions=True))

        issuer = set()
        owner = set()
        for data in results:
            if isinstance(data, Exception):
                logging.warning('Failed to load document: %s' % data)
                logging.exception(data)
                continue

            document = PortfolioPolicy.deserialize(data)

            if document.issuer != eid:
                owner.add(document)
            else:
                issuer.add(document)

        if PField.PRIVKEYS in config:
            portfolio = PrivatePortfolio()
        else:
            portfolio = Portfolio()

        portfolio.from_sets(issuer, owner)
        return portfolio

    async def reload_portfolio(
            self, portfolio: PrivatePortfolio, config: Tuple[str]) -> bool:
        """Reload portfolio."""
        dirname = '/portfolios/{0}'.format(portfolio.entity.id)
        if not self._archive.isdir(dirname):
            raise OSError(
                'Portfolio doesn\'t exists: %s' % portfolio.entity.id)

        result = self._archive.glob(
            name='{dir}/*'.format(dirname), owner=portfolio.entity.id)

        files = set()
        for field in config:
            pattern = PORTFOLIO_PATTERN[field]
            for filename in result:
                if pattern == filename[-4:]:
                    files.add(filename)

        available = set()
        for filename in files:
            available.add(PortfolioPolicy.path2fileident(filename))

        issuer, owner = portfolio.to_sets()
        loaded = set()
        for doc in issuer + owner:
            loaded.add(PortfolioPolicy.doc2fileident(doc))

        toload = available - loaded
        files2 = set()
        for filename in files:
            if PortfolioPolicy.path2fileident(filename) not in toload:
                files2.add(filename)

        files = files - files2

        ops = []
        for doc in files:
            ops.append(self._proxy.call(
                self._archive.load, filename=doc))

        results = await asyncio.shield(
            asyncio.gather(*ops, return_exceptions=True))

        issuer = set()
        owner = set()
        for data in results:
            if isinstance(data, Exception):
                logging.warning('Failed to load document: %s' % data)
                continue

            document = PortfolioPolicy.deserialize(data)

            if document.issuer != portfolio.entity.id:
                owner.add(document)
            else:
                issuer.add(document)

        portfolio.from_sets(issuer, owner)
        return portfolio

    async def save_portfolio(
            self, portfolio: PrivatePortfolio) -> bool:
        """Save a changed portfolio."""
        dirname = '/portfolios/{0}'.format(portfolio.entity.id)
        if not self._archive.isdir(dirname):
            raise OSError(
                'Portfolio doesn\'t exists: %s' % portfolio.entity.id)

        files = self._archive.glob(
            name='{dir}/*'.format(dir=dirname), owner=portfolio.entity.id)

        ops = []
        save, _ = portfolio.to_sets()

        for doc in save:
            filename = DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id)
            if filename in files:
                ops.append(self._proxy.call(
                    self._archive.save, filename=filename,
                    data=msgpack.packb(doc.export_bytes(),
                                       use_bin_type=True, strict_types=True),
                    compression=Entry.COMP_NONE))
            else:
                created, updated, owner = Glue.doc_save(doc)
                ops.append(self._proxy.call(
                    self._archive.mkfile, filename=filename,
                    data=PortfolioPolicy.serialize(doc),
                    id=doc.id, created=created, updated=updated, owner=owner,
                    compression=Entry.COMP_NONE))

        results = await asyncio.shield(
            asyncio.gather(*ops, return_exceptions=True))

        success = True
        for result in results:
            if isinstance(result, Exception):
                success = False
                logging.warning('Failed to save document: %s' % result)
        return success

    async def save_settings(self, name: str, data: bytes) -> bool:
        """Save or update a settings file."""
        try:
            filename = '/settings/' + name
            if self._archive.isfile(filename):
                self._archive.save(filename, data)
            else:
                self._archive.mkfile(filename, data)
        except Exception as e:
            logging.exception(e)
            return False

        return True

    async def load_settings(self, name: str) -> bytes:
        """Load a settings file."""
        filename = '/settings/' + name
        if self._archive.isfile(filename):
            return self._archive.load(filename)
        return b''
