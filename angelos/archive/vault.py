import pickle as pck
import asyncio

from ..utils import Util

from ..document.entities import (
    Entity, PrivateKeys, Keys)
from ..document.domain import Domain, Node
from .archive7 import Archive7, Entry
from .helper import Glue, Globber, AsyncProxy


HIERARCHY = (
    '/',
    '/cache',
    '/contacts',
    '/contacts/favorites',
    '/contacts/friend',
    '/contacts/all',
    '/contacts/blocked',
    '/entities',
    '/entities/churches',
    '/entities/ministries',
    '/entities/persons',
    '/keys',
    '/messages',
    '/messages/inbox',
    '/messages/read',
    '/messages/drafts',
    '/messages/outbox',
    '/messages/sent',
    '/messages/spam',
    '/messages/trash',
    '/profiles',
    '/settings',
    '/settings/nodes',
)


class Vault:
    IDENTITY = '/identity.pickle'
    ENTITY = '/entities/entity.pickle'
    PROFILE = '/profile.pickle'
    PRIVATE = '/settings/private.pickle'
    KEYS_LINK = '/keys/public.link'
    DOMAIN = '/settings/domain.pickle'
    NETWORK = '/settings/network.pickle'

    def __init__(self, filename, secret):
        self._archive = Archive7.open(filename, secret, Archive7.Delete.HARD)
        self._closed = False
        self._proxy = AsyncProxy(200)

    @property
    def closed(self):
        return self._closed

    def close(self):
        if not self._closed:
            self._proxy.quit()
            self._archive.close()
            self._closed = True

    @staticmethod
    def setup(filename, entity, privkeys, keys, domain, node, secret):
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)
        Util.is_type(domain, Domain)
        Util.is_type(node, Node)

        arch = Archive7.setup(
            filename, secret, owner=entity.id,
            node=node.id, domain=domain.id, title='Vault')  # ,
        #  _type=None, role=None, use=None)

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

    def load_identity(self):
        load_ops = [
            self._proxy.call(self._archive.load, filename=Vault.ENTITY),
            self._proxy.call(self._archive.load, filename=Vault.PRIVATE),
            self._proxy.call(self._archive.load, filename=Vault.KEYS_LINK),
            self._proxy.call(self._archive.load, filename=Vault.DOMAIN),
            self._proxy.call(
                self._archive.load, filename='/settings/nodes/' + str(
                    self._archive.stats().node) + '.pickle')
        ]
        loop = asyncio.get_event_loop()
        gathering = asyncio.gather(
            *load_ops, loop=loop, return_exceptions=True)
        loop.run_until_complete(gathering)

        return [pck.loads(_) for _ in gathering.result()]

    async def save(self, filename, document):
        created, updated, owner = Glue.doc_save(document)

        return (
            await self._proxy.call(
                self._archive.mkfile, filename=filename, data=pck.dumps(
                    document, pck.DEFAULT_PROTOCOL),
                id=document.id, owner=owner, created=created, modified=updated,
                compression=Entry.COMP_NONE)
            )

    async def issuer(self, issuer, path='/', limit=1):
        def callback():
            result = Globber.owner(self._archive, issuer, path)
            result.sort(reverse=True, key=lambda e: e[2])

            datalist = []
            for r in result[:limit]:
                datalist.append(self._archive.load(r[0]))

            return datalist

        return (
            await self._proxy.call(callback, 0, 5)
        )
