import pickle as pck

from ..utils import Util

from ..document.entities import Entity, PrivateKeys, Keys
from ..document.domain import Domain, Node
from .archive7 import Archive7, Entry
from .helper import Glue


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
        self.__archive = Archive7.open(filename, secret, Archive7.Delete.HARD)
        self.__closed = False
        self.load_identity()

    @property
    def closed(self):
        return self.__closed

    def save(self, filename, document):
        created, updated, owner = Glue.doc_save(document)

        self.__archive.mkfile(
            filename, data=pck.dumps(document, pck.DEFAULT_PROTOCOL),
            id=document.id, owner=owner, created=created, modified=updated,
            compression=Entry.COMP_NONE)

    def load_identity(self):
        return (
            pck.loads(self.__archive.load(Vault.ENTITY)),
            pck.loads(self.__archive.load(Vault.PRIVATE)),
            pck.loads(self.__archive.load(Vault.KEYS_LINK)),
            pck.loads(self.__archive.load(Vault.DOMAIN)),
            pck.loads(self.__archive.load('/settings/nodes/' + str(
                self.__archive.stats().node) + '.pickle')))

    def close(self):
        if not self.__closed:
            self.__archive.close()
            self.__closed = True

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

        files = [
            (Vault.ENTITY, entity),
            (Vault.PRIVATE, privkeys),
            ('/keys/' + str(keys.id) + '.pickle', keys),
            (Vault.DOMAIN, domain),
            ('/settings/nodes/' + str(node.id) + '.pickle', node),
        ]

        for f in files:
            created, updated, owner = Glue.doc_save(f[1])
            arch.mkfile(
                f[0], data=pck.dumps(
                    f[1].export(), pck.DEFAULT_PROTOCOL),
                id=f[1].id, owner=owner, created=created, modified=updated,
                compression=Entry.COMP_NONE)

        arch.link(Vault.KEYS_LINK, '/keys/' + str(keys.id) + '.pickle')
        arch.close()

        return Vault(filename, secret)
