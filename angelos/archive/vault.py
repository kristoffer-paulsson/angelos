import datetime as dt
import pickle as pck

from ..utils import Util

from ..document.entities import Entity, PrivateKeys, Keys
from ..document.domain import Domain, Node
from .archive7 import Archive7, Entry


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
    '/settings/keys'
    '/settings/nodes',
)


class Vault:
    def __init__(self, filename, secret):
        self.__archive = Archive7.open(filename, secret, Archive7.Delete.HARD)
        self.__closed = False

    @property
    def closed(self):
        return self.__closed

    def save(self, filename, document):
        try:
            owner = document.owner
        except AttributeError:
            owner = document.issuer

        try:
            updated = dt.datetime.combine(
                document.updated, dt.datetime.min.time())
        except (AttributeError, TypeError):
            updated = None

        created = dt.datetime.combine(
            document.created, dt.datetime.min.time())

        self._archive.mkfile(
            filename, data=pck.dumps(document.export(), pck.DEFAULT_PROTOCOL),
            id=document.id, owner=owner, created=created, modified=updated,
            compression=Entry.COMP_NONE)

    def close(self):
        if not self.__closed:
            self.__archive.close()
            self.__closed = True

    @staticmethod
    def setup(filename, entity, pk, keys, domain, node):
        Util.is_type(entity, Entity)
        Util.is_type(pk, PrivateKeys)
        Util.is_type(keys, Keys)
        Util.is_type(domain, Domain)
        Util.is_type(node, Node)

        arch = Archive7.setup(
            filename, pk.secret, owner=entity.id,
            node=node.id, domain=domain.id, title='Vault')  # ,
        #  _type=None, role=None, use=None)

        for i in HIERARCHY:
            arch.mkdir(i)

        arch.save('/settings/' + entity.id + '.pickle', entity)
        arch.save('/settings/private.pickle', pk)
        arch.save('/settings/keys/' + keys.id + '.pickle', keys)
        arch.save('/settings/domain.pickle', domain)
        arch.save('/settings/nodes/' + node.id + '.pickle', node)
        arch.close()

        return Vault(filename, pk.secret)
