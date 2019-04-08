import datetime

from ..utils import Util
from .archive7 import Archive7


class Glue:
    @staticmethod
    def doc_save(document):
        try:
            owner = document.owner
        except AttributeError:
            owner = document.issuer

        try:
            updated = datetime.datetime.combine(
                document.updated, datetime.datetime.min.time())
        except (AttributeError, TypeError):
            updated = None

        created = datetime.datetime.combine(
            document.created, datetime.datetime.min.time())

        return created, updated, owner


class Globber:
    @staticmethod
    def full(archive, filename='*', cmp_uuid=False):
        Util.is_type(archive, Archive7)

        archive._lock()

        sq = Archive7.Query(pattern=filename)
        sq.type(b'f')
        idxs = archive.ioc.entries.search(sq)
        ids = archive.ioc.hierarchy.ids

        files = {}
        for i in idxs:
            idx, entry = i
            if entry.parent.int == 0:
                name = '/'+str(entry.name, 'utf-8')
            else:
                name = ids[entry.parent]+'/'+str(entry.name, 'utf-8')
            if cmp_uuid:
                files[entry.id] = (name, entry.deleted, entry.modified)
            else:
                files[name] = (entry.id, entry.deleted, entry.modified)

        archive._unlock()
        return files
