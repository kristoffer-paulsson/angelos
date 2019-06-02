# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Vault.
"""
import pickle as pck
import asyncio
import uuid
import logging
import atexit
from typing import Tuple

import msgpack

from ..policy import (
    Portfolio, PrivatePortfolio, PField, DOCUMENT_PATH, PORTFOLIO_PATTERN,
    PortfolioPolicy)
from .archive7 import Archive7, Entry
from .helper import Glue, Globber, AsyncProxy


HIERARCHY = (
    '/',
    '/cache',
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
    # Networks, for other hostts that are strusted
    '/networks'
    # Preferences by the owning entity.
    '/settings',
    '/settings/nodes',

    '/portfolios'
)


class Vault:
    """
    Vault interface.

    The Vault is the most important archive in a facade, because it contains
    the private entity data.
    """

    NODES = '/settings/nodes'
    INBOX = '/messages/inbox/'

    def __init__(self, filename, secret):
        """Initialize the Vault."""
        self._archive = Archive7.open(filename, secret, Archive7.Delete.HARD)
        atexit.register(self._archive.close)
        self.__stats = self._archive.stats()
        self._closed = False
        self._proxy = AsyncProxy(200)

    @property
    def stats(self):
        """Stats of underlying archive."""
        return self.__stats

    @property
    def closed(self):
        """Indicate if vault is closed."""
        return self._closed

    def close(self):
        """Close the Vault."""
        if not self._closed:
            self._proxy.quit()
            atexit.unregister(self._archive.close)
            self._archive.close()
            self._closed = True

    @staticmethod
    def setup(filename, secret, portfolio: PrivatePortfolio,
              _type=None, role=None, use=None):
        """Create and setup the whole Vault according to policys."""

        arch = Archive7.setup(
            filename, secret, owner=portfolio.entity.id,
            node=next(iter(portfolio.nodes)).id,
            domain=portfolio.domain.id, title='Vault',
            _type=_type, role=role, use=use)

        for i in HIERARCHY:
            arch.mkdir(i)

        """
        key_path = '/keys/' + str(next(iter(portfolio.keys)).id) + '.pickle'
        files = [
            (Vault.ENTITY, portfolio.entity),
            (Vault.PRIVATE, portfolio.privkeys),
            (Vault.DOMAIN, portfolio.domain),
        ]
        for node in portfolio.nodes:
            files.append(
                ('/settings/nodes/' + str(node.id) + '.pickle', node)),

        for keys in portfolio.keys:
            files.append(
                ('/keys/' + str(keys.id) + '.pickle', keys)),

        if portfolio.network:
            files.append((Vault.NETWORK, portfolio.network))

        for f in files:
            created, updated, owner = Glue.doc_save(f[1])
            arch.mkfile(
                f[0], data=pck.dumps(
                    f[1], pck.DEFAULT_PROTOCOL),
                id=f[1].id, owner=owner, created=created, modified=updated,
                compression=Entry.COMP_NONE)

        arch.link(Vault.KEYS_LINK, key_path)
        """
        arch.close()

        return Vault(filename, secret)

    async def load_identity(self):
        """Load the entity core documents."""
        load_ops = [
            self._proxy.call(self._archive.load, filename=Vault.ENTITY),
            self._proxy.call(self._archive.load, filename=Vault.PRIVATE),
            self._proxy.call(self._archive.load, filename=Vault.KEYS_LINK),
            self._proxy.call(self._archive.load, filename=Vault.DOMAIN),
            self._proxy.call(
                self._archive.load, filename='/settings/nodes/' + str(
                    self._archive.stats().node) + '.pickle')
        ]
        result = await asyncio.gather(*load_ops, return_exceptions=True)
        return [pck.loads(_) for _ in result]

    async def load_network(self):
        """Load the entity core documents."""
        return pck.loads(await self._proxy.call(
            self._archive.load, filename=Vault.NETWORK))

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

    async def search(self, issuer=None, path='/', limit=1):
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
            self, id: uuid.UUID, config: Tuple[str]) -> Portfolio:
        """Load portfolio from uuid."""
        dirname = '/portfolios/{0}'.format(id)
        if not self._archive.isdir(dirname):
            raise OSError('Portfolio doesn\'t exists: %s' % id)

        result = self._archive.glob(name='{0}/*'.format(dirname), owner=id)

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

            if document.issuer.int != id.int:
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
            raise OSError('Portfolio doesn\'t exists: %s' % id)

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

            if document.issuer.int != id.int:
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
            raise OSError('Portfolio doesn\'t exists: %s' % id)

        files = self._archive.glob(
            name='{dir}/*'.format(dirname), owner=portfolio.entity.id)

        ops = []
        save = portfolio._save | portfolio.issuer._save | portfolio.owner._save

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

        portfolio.reset()
        portfolio.issuer.reset()
        portfolio.owner.reset()

        success = True
        for result in results:
            if isinstance(result, Exception):
                success = False
                logging.warning('Failed to save document: %s' % result)
        return success
