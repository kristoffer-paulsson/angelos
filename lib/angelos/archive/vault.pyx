# cython: language_level=3
"""Vault."""
import pickle as pck
import asyncio
import uuid

from ..policy import Portfolio, PrivatePortfolio
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

    def new_portfolio(self, portfolio: Portfolio) -> bool:
        """Save a portfolio for the first time."""
        raise NotImplementedError()

    def load_portfolio(self, id: uuid.UUID) -> Portfolio:
        """Load portfolio from uuid."""
        raise NotImplementedError()

    def reload_portfolio(self, portfolio: PrivatePortfolio) -> bool:
        """Reload portfolio."""
        raise NotImplementedError()

    def save_portfolio(
            self, portfolio: PrivatePortfolio) -> bool:
        """Save a changed portfolio."""
        raise NotImplementedError()
