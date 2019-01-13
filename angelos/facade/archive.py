import threading
import uuid
import pickle
import datetime

from .archive7 import Archive, Entry
from .conceal import ConcealIO


class BaseArchive:
    def __init__(self, path, secret):
        self._thread_lock = threading.Lock()

        full_path = path + '/' + self.NAME
        self._archive = Archive(ConcealIO(
            full_path, secret, 'w'))

    @property
    def archive(self):
        return self._archive


class Entity(BaseArchive):
    NAME = 'default.ar7.cnl'

    @staticmethod
    def setup(path, secret, entity, network):
        hierarchy = (
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
        full_path = path + '/' + Entity.NAME
        open(full_path, 'a').close()
        fileobj = ConcealIO(full_path, secret, 'w')
        archive = Archive.setup(
            fileobj, owner=entity.id, node=uuid.uuid4(),
            title=b'Entity Master Archive', network=network.id, _type=None,
            role=None, use=None)
        for i in hierarchy:
            archive.mkdir(i)
        archive.close()
        return Entity(path, secret)

    def create(self, path, obj):
        try:
            owner = obj.owner
        except AttributeError:
            owner = obj.issuer

        try:
            updated = datetime.datetime.combine(
                obj.updated, datetime.datetime.min.time())
        except (AttributeError, TypeError):
            updated = None

        created = datetime.datetime.combine(
            obj.created, datetime.datetime.min.time())

        self._archive.mkfile(
            path, data=pickle.dumps(obj.export(), pickle.DEFAULT_PROTOCOL),
            id=obj.id, owner=owner, created=created, modified=updated,
            compression=Entry.COMP_BZIP2)

    def read(self, path):
        return self._archive.load(path)

    def update(self, path, obj):
        self._archive.save(
            path, data=pickle.dumps(obj.export()),
            compression=Entry.COMP_BZIP2)

    def delete(self, path):
        self._archive.remove(path)

    def search(self, path, owner):
        pid = self._archive.ioc.operations.get_pid(path)
        query = Archive.Query().parent(pid).owner(owner).deleted(False)
        entries = self._archive.ioc.entries.search(query)
        objects = []
        for i in entries:
            objects.append(
                pickle.loads(
                    self._archive.ioc.operations.load_data(i[1])))
        return objects


class Files(BaseArchive):
    def _name(self):
        return 'files.ar7.cnl'

    def _hierarchy(self):
        return (
            '/',
            '/desktop',
            '/documents',
            '/downloads',
            '/favorites',
            '/links',
            '/pictures',
            '/templates',
            '/videos',
        )
