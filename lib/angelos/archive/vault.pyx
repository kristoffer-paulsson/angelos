# cython: language_level=3
"""Vault."""
import pickle as pck
import asyncio
import uuid
import logging
from typing import Tuple
from collections.abc import Iterable

import msgpack

from ..policy import Portfolio, PrivatePortfolio, PField
from .archive7 import Archive7, Entry
from .helper import Glue, Globber, AsyncProxy
from ..document import (
    DocType, PrivateKeys, Keys, Person, Ministry, Church, PersonProfile,
    MinistryProfile, ChurchProfile, Domain, Node, Network, Verified, Trusted,
    Revoked, Envelope, Note, Instant, Mail, Share, Report)


HIERARCHY = (
    '/',
    '/cache',
    # Contact profiles and links based on directory.
    '/contacts',
    '/contacts/favorites',
    '/contacts/friend',
    '/contacts/all',
    '/contacts/blocked',
    # Imported entities
    '/entities',
    '/entities/churches',
    '/entities/ministries',
    '/entities/persons',
    # Issued statements by the vaults entity
    '/issued',
    '/issued/verified',
    '/issued/trusted',
    '/issued/revoked',
    # Public keys, mainly from other entities
    '/keys',
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
    # Pool with imported statements about entity and others
    '/pool',
    '/pool/verified',
    '/pool/trusted',
    '/pool/revoked',
    # Imported entities profiles anv v-cards.
    '/profiles',
    # Preferences by the owning entity.
    '/settings',
    '/settings/nodes',

    '/portfolios'
)

PORTFOLIO_TEMPLATE = {
    PField.ENTITY: '{dir}/{file}.ent',
    PField.PROFILE: '{dir}/{file}.pfl',
    PField.PRIVKEYS: '{dir}/{file}.pky',
    PField.KEYS: '{dir}/{file}.key',
    PField.DOMAIN: '{dir}/{file}.dmn',
    PField.NODES: '{dir}/{file}.nod',
    PField.NET: '{dir}/{file}.net',
    PField.ISSUER_VERIFIED: '{dir}/{file}.ver',
    PField.ISSUER_TRUSTED: '{dir}/{file}.rst',
    PField.ISSUER_REVOKED: '{dir}/{file}.rev',
    PField.OWNER_VERIFIED: '{dir}/{file}.ver',
    PField.OWNER_TRUSTED: '{dir}/{file}.rst',
    PField.OWNER_REVOKED: '{dir}/{file}.rev'
}

PORTFOLIO_PATTERN = {
    PField.ENTITY: '.ent',
    PField.PROFILE: 'pfl',
    PField.PRIVKEYS: '.pky',
    PField.KEYS: '.key',
    PField.DOMAIN: '.dmn',
    PField.NODES: '.nod',
    PField.NET: '.net',
    PField.ISSUER_VERIFIED: '.ver',
    PField.ISSUER_TRUSTED: '.rst',
    PField.ISSUER_REVOKED: '.rev',
    PField.OWNER_VERIFIED: '.ver',
    PField.OWNER_TRUSTED: '.rst',
    PField.OWNER_REVOKED: '.rev'
}

DOCUMENT_TYPE = {
    DocType.KEYS_PRIVATE: PrivateKeys,
    DocType.KEYS: Keys,
    DocType.ENTITY_PERSON: Person,
    DocType.ENTITY_MINISTRY: Ministry,
    DocType.ENTITY_CHURCH: Church,
    DocType.PROF_PERSON: PersonProfile,
    DocType.PROF_MINISTRY: MinistryProfile,
    DocType.PROF_CHURCH: ChurchProfile,
    DocType.NET_DOMAIN: Domain,
    DocType.NET_NODE: Node,
    DocType.NET_NETWORK: Network,
    DocType.STAT_VERIFIED: Verified,
    DocType.STAT_TRUSTED: Trusted,
    DocType.STAT_REVOKED: Revoked,
    DocType.COM_ENVELOPE: Envelope,
    DocType.COM_NOTE: Note,
    DocType.COM_INSTANT: Instant,
    DocType.COM_MAIL: Mail,
    DocType.COM_SHARE: Share,
    DocType.COM_REPORT: Report,
}


class Vault:
    """
    Vault interface.

    The Vault is the most important archive in a facade, because it contains
    the private entity data.
    """

    IDENTITY = '/identity.pickle'
    ENTITY = '/entities/entity.pickle'
    PROFILE = '/profile.pickle'
    PRIVATE = '/settings/private.pickle'
    KEYS_LINK = '/keys/public.link'
    DOMAIN = '/settings/domain.pickle'
    NODES = '/settings/nodes'
    NETWORK = '/settings/network.pickle'

    INBOX = '/messages/inbox/*'

    def __init__(self, filename, secret):
        """Initialize the Vault."""
        self._archive = Archive7.open(filename, secret, Archive7.Delete.HARD)
        self._closed = False
        self._proxy = AsyncProxy(200)

    @property
    def closed(self):
        """Indicate if vault is closed."""
        return self._closed

    def close(self):
        """Close the Vault."""
        if not self._closed:
            self._proxy.quit()
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
                self._archive.mkfile, filename=filename, data=pck.dumps(
                    document, pck.DEFAULT_PROTOCOL),
                id=document.id, owner=owner, created=created, modified=updated,
                compression=Entry.COMP_NONE)
            )

    async def update(self, filename, document):
        """Update a document on file."""
        created, updated, owner = Glue.doc_save(document)

        return (
            await self._proxy.call(
                self._archive.save, filename=filename, data=pck.dumps(
                    document, pck.DEFAULT_PROTOCOL), modified=updated)
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

        files = []
        self._archive.mkdir(dirname)
        for name, doc in portfolio._disassemble():
            if isinstance(doc, Iterable):
                for item in doc:
                    files.append(
                        (PORTFOLIO_TEMPLATE[name].format(
                            dirname, item.id), item))
            else:
                files.append(
                    (PORTFOLIO_TEMPLATE[name].format(dirname, doc.id), doc))

        ops = []
        for doc in files:
            created, updated, owner = Glue.doc_save(doc[1])
            ops.append(self._proxy.call(
                self._archive.mkfile, filename=doc[0],
                data=msgpack.packb(
                    doc[1].export_bytes(), use_bin_type=True, use_list=False),
                id=doc[1].id, created=created, updated=updated, owner=owner,
                compression=Entry.COMP_NONE))

        results = await asyncio.shield(
            asyncio.gather(*ops, return_exceptions=True))
        success = True
        for result in results:
            if isinstance(result, Exception):
                success = False
                logging.warning('Failed to save document: %s' % result)
        return success

    async def load_portfolio(
            self, id: uuid.UUID, config: Tuple[str]) -> Portfolio:
        """Load portfolio from uuid."""
        dirname = '/portfolios/{0}'.format(id)
        if not self._archive.isdir(dirname):
            raise OSError('Portfolio doesn\'t exists: %s' % id)

        result = self._archive.glob(name='{dir}/*'.format(dirname), owner=id)

        files = []
        for field in config:
            pattern = PORTFOLIO_PATTERN[field]
            for filename in result:
                if pattern == filename[-4:]:
                    files.append(filename)

        ops = []
        for doc in files:
            ops.append(self._proxy.call(
                self._archive.load, filename=doc))

        results = await asyncio.shield(
            asyncio.gather(*ops, return_exceptions=True))

        if PField.PRIVKEYS in config:
            portfolio = PrivatePortfolio()
        else:
            portfolio = Portfolio()

        for data in results:
            if isinstance(data, Exception):
                logging.warning('Failed to load document: %s' % data)
                continue

            docobj = msgpack.unpackb(data, raw=False, use_list=False)
            document = DOCUMENT_TYPE[docobj['type']].build(docobj)

            if isinstance(document, (Person, Ministry, Church)):
                portfolio.entity = document

            if isinstance(document, (
                    PersonProfile, MinistryProfile, ChurchProfile)):
                portfolio.profile = document

            if isinstance(document, PrivateKeys):
                portfolio.privkeys = document

            if isinstance(document, Domain):
                portfolio.domain = document

            if isinstance(document, Network):
                portfolio.network = document

            if isinstance(document, Keys):
                portfolio.keys.append(document)

            if isinstance(document, Node):
                portfolio.nodes.add(document)

            if document.issuer.int != id.int:
                if isinstance(document, Verified):
                    portfolio.owner.verified.add(document)

                if isinstance(document, Trusted):
                    portfolio.owner.trusted.add(document)

                if isinstance(document, Revoked):
                    portfolio.owner.revoked.add(Revoked)
            else:
                if isinstance(document, Verified):
                    portfolio.issuer.verified.add(document)

                if isinstance(document, Trusted):
                    portfolio.issuer.trusted.add(document)

                if isinstance(document, Revoked):
                    portfolio.issuer.revoked.add(Revoked)

        return portfolio

    def reload_portfolio(
            self, portfolio: PrivatePortfolio, config: Tuple[str]) -> bool:
        """Reload portfolio."""
        raise NotImplementedError()

    def save_portfolio(
            self, portfolio: PrivatePortfolio) -> bool:
        """Save a changed portfolio."""
        raise NotImplementedError()
