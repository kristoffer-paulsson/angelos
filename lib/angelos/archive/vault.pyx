# cython: language_level=3
"""Vault."""
import pickle as pck
import asyncio

from ..utils import Util

from ..document.entities import (
    Entity, PrivateKeys, Keys)
from ..document.domain import Domain, Node, Network
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
    def setup(filename, secret,
              entity, privkeys, keys, domain, node,
              network=None, _type=None, role=None, use=None):
        """Create and setup the whole Vault according to policys."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)
        Util.is_type(domain, Domain)
        Util.is_type(node, Node)
        Util.is_type(network, (Network, type(None)))

        arch = Archive7.setup(
            filename, secret, owner=entity.id,
            node=node.id, domain=domain.id, title='Vault',
            _type=_type, role=role, use=use)

        for i in HIERARCHY:
            arch.mkdir(i)

        key_path = '/keys/' + str(keys.id) + '.pickle'
        files = [
            (Vault.ENTITY, entity),
            (Vault.PRIVATE, privkeys),
            (key_path, keys),
            (Vault.DOMAIN, domain),
            ('/settings/nodes/' + str(node.id) + '.pickle', node),
        ]
        if network:
            files.append((Vault.NETWORK, network))

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
        def callback():
            result = Globber.owner(self._archive, issuer, path)
            result.sort(reverse=True, key=lambda e: e[2])

            datalist = []
            for r in result[:limit]:
                datalist.append(self._archive.load(r[0]))

            return datalist

        return (await self._proxy.call(callback, 0, 5))
