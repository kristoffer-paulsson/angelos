import os
import re
import struct
import collections
import uuid
import time
import datetime
import enum
import hashlib
import sys
import math
import threading
import copy
import zlib
import gzip
import bz2
import logging

from ..ioc import Container, ContainerAware
from ..utils import Util
from ..error import Error
from .conceal import ConcealIO


class Header(collections.namedtuple('Header', field_names=[
    'major',        # 2
    'minor',        # 2
    'type',         # 1
    'role',         # 1
    'use',          # 1
    'id',           # 16
    'owner',        # 16
    'domain',       # 16
    'node',         # 16
    'created',      # 8
    'title',        # 128
    'entries',      # 4
], defaults=(
    1,
    0,
    0,
    0,
    0,
    uuid.uuid4(),
    None,
    None,
    None,
    datetime.datetime.now(),
    None,
    8,
))):
    __slots__ = ()
    FORMAT = '!8sHHbbb16s16s16s16sQ128sL805x'

    @staticmethod
    def header(owner, id=None, node=None, domain=None, title=None, _type=None,
               role=None, use=None, major=1, minor=0, entries=8):
        Util.is_type(owner, uuid.UUID)
        Util.is_type(id, (uuid.UUID, type(None)))
        Util.is_type(node, (uuid.UUID, type(None)))
        Util.is_type(domain, (uuid.UUID, type(None)))
        Util.is_type(title, (bytes, bytearray, type(None)))
        Util.is_type(_type, (int, type(None)))
        Util.is_type(role, (int, type(None)))
        Util.is_type(use, (int, type(None)))
        Util.is_type(major, int)
        Util.is_type(minor, int)
        Util.is_type(entries, int)

        if not id:
            id = uuid.uuid4()

        return Header(
            major=major,
            minor=minor,
            type=_type,
            role=role,
            use=use,
            id=id,
            owner=owner,
            domain=domain,
            node=node,
            created=datetime.datetime.now(),
            title=title,
            entries=entries
        )

    def serialize(self):
        return struct.pack(
            Header.FORMAT,
            b'archive7',
            1,
            0,
            self.type if not isinstance(
                self.type, type(None)) else 0,
            self.role if not isinstance(
                self.role, type(None)) else 0,
            self.use if not isinstance(
                self.use, type(None)) else 0,
            self.id.bytes if isinstance(
                self.id, uuid.UUID) else uuid.uuid4().bytes,
            self.owner.bytes if isinstance(
                self.owner, uuid.UUID) else b'\x00'*16,
            self.domain.bytes if isinstance(
                self.domain, uuid.UUID) else b'\x00'*16,
            self.node.bytes if isinstance(
                self.node, uuid.UUID) else b'\x00'*16,
            int(time.mktime(self.created.timetuple(
                )) if isinstance(self.created, datetime.datetime
                                 ) else time.mktime(datetime.datetime.now(
                                    ).timetuple())),
            self.title[:128] if isinstance(
                self.title, (bytes, bytearray)) else b'\x00'*128,
            self.entries if isinstance(self.entries, int) else 8
        )

    @staticmethod
    def deserialize(data):
        Util.is_type(data, (bytes, bytearray))
        t = struct.unpack(Header.FORMAT, data)

        if t[0] != b'archive7':
            raise Util.exception(Error.AR7_INVALID_FORMAT, {'format': t[0]})

        return Header(
            major=t[1],
            minor=t[2],
            type=t[3],
            role=t[4],
            use=t[5],
            id=uuid.UUID(bytes=t[6]),
            owner=uuid.UUID(bytes=t[7]),
            domain=uuid.UUID(bytes=t[8]),
            node=uuid.UUID(bytes=t[9]),
            created=datetime.datetime.fromtimestamp(t[10]),
            title=t[11].strip(b'\x00'),
            entries=t[12]
        )


class Entry(collections.namedtuple('Entry', field_names=[
    'type',         # 1
    'id',           # 16
    'parent',       # 16
    'owner',        # 16
    'created',      # 8
    'modified',     # 8
    'offset',       # 8
    'size',         # 8
    'length',       # 8
    'compression',  # 1
    'deleted',      # 1
    # padding'      # 17
    'digest',       # 20
    'name'          # 128
], defaults=(
    b'b',
    uuid.uuid4(),  # Always generate manually
    uuid.UUID(bytes=b'\x00'*16),
    uuid.UUID(bytes=b'\x00'*16),
    datetime.datetime.fromtimestamp(0),  # Always generate manually
    datetime.datetime.fromtimestamp(0),  # Always generate manually
    None,
    None,
    None,
    0,
    False,
    # None,
    None,
    None
))):
    __slots__ = ()
    FORMAT = '!c16s16s16sqqQQQb?17x20s128s'
    TYPE_FILE = b'f'    # Represents a file
    TYPE_LINK = b'l'     # Represents a link
    TYPE_DIR = b'd'     # Represents a directory
    TYPE_EMPTY = b'e'   # Represents an empty block
    TYPE_BLANK = b'b'   # Represents an empty entry
    COMP_NONE = 0
    COMP_ZIP = 1
    COMP_GZIP = 2
    COMP_BZIP2 = 3

    @staticmethod
    def blank():
        kwargs = {
            'type': Entry.TYPE_BLANK,
            'id': uuid.uuid4(),
        }
        return Entry(**kwargs)

    @staticmethod
    def empty(offset, size):
        Util.is_type(offset, int)
        Util.is_type(size, int)

        kwargs = {
            'type': Entry.TYPE_EMPTY,
            'id': uuid.uuid4(),
            'offset': offset,
            'size': size,
        }
        return Entry(**kwargs)

    @staticmethod
    def dir(name, parent=None, owner=None, created=None, modified=None):
        Util.is_type(name, str)
        Util.is_type(parent, (type(None), uuid.UUID))
        Util.is_type(owner, (type(None), uuid.UUID))
        Util.is_type(created, (type(None), datetime.datetime))
        Util.is_type(modified, (type(None), datetime.datetime))

        kwargs = {
            'type': Entry.TYPE_DIR,
            'id': uuid.uuid4(),
            'created': datetime.datetime.now(),
            'modified': datetime.datetime.now(),
            'name': name.encode('utf-8')[:128]
        }

        if parent:
            kwargs['parent'] = parent
        if owner:
            kwargs['owner'] = owner
        if created:
            kwargs['created'] = created
        if modified:
            kwargs['modified'] = modified

        return Entry(**kwargs)

    @staticmethod
    def link(name, link, parent=None, created=None, modified=None):
        Util.is_type(name, str)
        Util.is_type(parent, (type(None), uuid.UUID))
        Util.is_type(link, uuid.UUID)
        Util.is_type(created, (type(None), datetime.datetime))
        Util.is_type(modified, (type(None), datetime.datetime))

        kwargs = {
            'type': Entry.TYPE_LINK,
            'id': uuid.uuid4(),
            'owner': link,
            'created': datetime.datetime.now(),
            'modified': datetime.datetime.now(),
            'name': name.encode('utf-8')[:128]
        }

        if parent:
            kwargs['parent'] = parent
        if created:
            kwargs['created'] = created
        if modified:
            kwargs['modified'] = modified

        return Entry(**kwargs)

    @staticmethod
    def file(name, offset, size, digest, id=None, parent=None, owner=None,
             created=None, modified=None, compression=None, length=None):
        Util.is_type(name, str)
        Util.is_type(offset, int)
        Util.is_type(size, int)
        Util.is_type(digest, bytes)
        Util.is_type(id, (type(None), uuid.UUID))
        Util.is_type(parent, (type(None), uuid.UUID))
        Util.is_type(owner, (type(None), uuid.UUID))
        Util.is_type(created, (type(None), datetime.datetime))
        Util.is_type(modified, (type(None), datetime.datetime))
        Util.is_type(compression, (type(None), int))
        Util.is_type(length, (type(None), int))

        kwargs = {
            'type': Entry.TYPE_FILE,
            'id': uuid.uuid4(),
            'created': datetime.datetime.now(),
            'modified': datetime.datetime.now(),
            'offset': offset,
            'size': size,
            'digest': digest[:20],
            'name': name.encode('utf-8')[:128]
        }

        if id:
            kwargs['id'] = id
        if parent:
            kwargs['parent'] = parent
        if owner:
            kwargs['owner'] = owner
        if created:
            kwargs['created'] = created
        if modified:
            kwargs['modified'] = modified
        if compression and length:
            if 1 <= compression <= 3 and not isinstance(length, int):
                raise Util.exception(Error.AR7_INVALID_COMPRESSION, {
                    'compression': compression})
            kwargs['compression'] = compression
            kwargs['length'] = length
        else:
            kwargs['length'] = size

        return Entry(**kwargs)

    def serialize(self):
        return struct.pack(
            Entry.FORMAT,
            self.type if not isinstance(
                self.type, type(None)) else Entry.TYPE_BLANK,
            self.id.bytes if isinstance(
                self.id, uuid.UUID) else uuid.uuid4().bytes,
            self.parent.bytes if isinstance(
                self.parent, uuid.UUID) else b'\x00'*16,
            self.owner.bytes if isinstance(
                self.owner, uuid.UUID) else b'\x00'*16,
            int(time.mktime(self.created.timetuple(
                )) if isinstance(self.created, datetime.datetime
                                 ) else time.mktime(datetime.datetime.now(
                                    ).timetuple())),
            int(time.mktime(self.modified.timetuple(
                )) if isinstance(self.modified, datetime.datetime
                                 ) else time.mktime(datetime.datetime.now(
                                    ).timetuple())),
            self.offset if isinstance(self.offset, int) else 0,
            self.size if isinstance(self.size, int) else 0,
            self.length if isinstance(self.length, int) else 0,
            self.compression if isinstance(
                self.compression, int) else Entry.COMP_NONE,
            self.deleted if isinstance(self.deleted, bool) else False,
            # b'\x00'*17,
            self.digest if isinstance(
                self.digest, (bytes, bytearray)) else b'\x00'*20,
            self.name[:128] if isinstance(
                self.name, (bytes, bytearray)) else b'\x00'*128
        )

    @staticmethod
    def deserialize(data):
        Util.is_type(data, (bytes, bytearray))
        t = struct.unpack(Entry.FORMAT, data)
        return Entry(
            type=t[0],
            id=uuid.UUID(bytes=t[1]),
            parent=uuid.UUID(bytes=t[2]),
            owner=uuid.UUID(bytes=t[3]),
            created=datetime.datetime.fromtimestamp(t[4]),
            modified=datetime.datetime.fromtimestamp(t[5]),
            offset=t[6],
            size=t[7],
            length=t[8],
            compression=t[9],
            deleted=t[10],
            digest=t[11],
            name=t[12].strip(b'\x00')
        )


class Archive7(ContainerAware):
    BLOCK_SIZE = 512

    def __init__(self, fileobj, delete=3):
        self.__closed = False
        self.__lock = threading.Lock()
        self.__file = fileobj
        self.__size = os.path.getsize(self.__file.name)
        self.__delete = delete if delete else Archive7.Delete.ERASE
        self.__file.seek(0)
        self.__header = Header.deserialize(self.__file.read(
                struct.calcsize(Header.FORMAT)))

        self.__file.seek(1024)
        entries = []
        for i in range(self.__header.entries):
            entries.append(Entry.deserialize(self.__file.read(
                    struct.calcsize(Entry.FORMAT))))

        ContainerAware.__init__(self, Container(config={
            'archive': lambda s: self,
            'entries': lambda s: Archive7.Entries(s, entries),
            'hierarchy': lambda s: Archive7.Hierarchy(s),
            'operations': lambda s: Archive7.Operations(s),
            'fileobj': lambda s: self.__file
        }))

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    @staticmethod
    def setup(filename, secret, owner=None, node=None, title=None,
              domain=None, _type=None, role=None, use=None):
        Util.is_type(filename, (str, bytes))
        Util.is_type(secret, (str, bytes))

        with ConcealIO(filename, 'wb', secret=secret):
            pass
        fileobj = ConcealIO(filename, 'rb+', secret=secret)

        header = Header.header(
            owner=owner, node=node, title=str(title).encode(),
            domain=domain, _type=_type, role=role, use=use)

        fileobj.write(header.serialize())
        for i in range(header.entries):
            fileobj.write(Entry.blank().serialize())
        fileobj.seek(0)

        return Archive7(fileobj)

    @staticmethod
    def open(filename, secret, delete=3):
        Util.is_type(filename, (str, bytes))
        Util.is_type(secret, (str, bytes))

        if not os.path.isfile(filename):
            raise Util.exception(Error.AR7_NOT_FOUND, {'path': filename})

        fileobj = ConcealIO(filename, 'rb+', secret=secret)
        return Archive7(fileobj, delete)

    @property
    def closed(self):
        return self.__closed

    @property
    def locked(self):
        return self.__lock.locked()

    def _lock(self):
        return self.__lock.acquire()

    def _unlock(self):
        self.__lock.release()

    def _update_header(self, cnt):
        header = self.__header._asdict()
        header['entries'] = cnt
        self.__header = Header(**header)
        self.ioc.operations.write_data(0, self.__header.serialize())

    def close(self):
        with self.__lock:
            if not self.__closed:
                self.__file.close()

    def stats(self):
        return copy.deepcopy(self.__header)

    def info(self, path):
        with self.__lock:
            ops = self.ioc.operations

            name, dirname = ops.path(path)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)

            return copy.deepcopy(entry)

    def glob(self, name='*', id=None, parent=None,
             owner=None, created=None, modified=None, deleted=None):
        with self.__lock:
            entries = self.ioc.entries
            ids = self.ioc.hierarchy.ids

            sq = Archive7.Query(pattern=name)
            if id:
                sq.id(id)
            if parent:
                sq.parent(parent)
            if owner:
                sq.owner(owner)
            if created:
                sq.created(created)
            if modified:
                sq.modified(modified)
            if deleted:
                sq.deleted(deleted)
            idxs = entries.search(sq)

            files = []
            for i in idxs:
                idx, entry = i
                if entry.parent.int == 0:
                    name = '/'+str(entry.name, 'utf-8')
                else:
                    name = ids[entry.parent]+'/'+str(entry.name, 'utf-8')
                files.append(name)

            return files

    def move(self, src, dest):
        with self.__lock:
            ops = self.ioc.operations

            name, dirname = ops.path(src)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)
            did = ops.get_pid(dest)
            ops.is_available(name, did)

            entry = entry._asdict()
            entry['parent'] = did
            entry = Entry(**entry)
            self.ioc.entries.update(entry, idx)

    def chmod(self, path, id=None, owner=None, deleted=None):
        with self.__lock:
            ops = self.ioc.operations

            name, dirname = ops.path(path)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)

            entry = entry._asdict()
            if id:
                entry['id'] = id
            if owner:
                entry['owner'] = owner
            if deleted:
                entry['deleted'] = deleted
            entry = Entry(**entry)
            self.ioc.entries.update(entry, idx)

    def remove(self, path, mode=None):
        with self.__lock:
            ops = self.ioc.operations
            entries = self.ioc.entries

            name, dirname = ops.path(path)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)

            # Check for unsupported types
            if entry.type not in (
                    Entry.TYPE_FILE, Entry.TYPE_DIR, Entry.TYPE_LINK):
                raise Util.exception(Error.AR7_WRONG_ENTRY, {
                    'type': entry.type, 'id': entry.id})

            # If directory is up for removal, check that it is empty or abort
            if entry.type == Entry.TYPE_DIR:
                cidx = entries.search(
                    Archive7.Query().parent(entry.id))
                if len(cidx):
                    raise Util.exception(Error.AR7_NOT_EMPTY, {
                        'index': cidx})

            if not mode:
                mode = self.__delete

            if mode == Archive7.Delete.ERASE:
                if entry.type == Entry.TYPE_FILE:
                    entries.update(
                        Entry.empty(
                            offset=entry.offset,
                            size=entries._sector(entry.size)),
                        idx)
                elif entry.type in (Entry.TYPE_DIR, Entry.TYPE_LINK):
                    entries.update(Entry.blank(), idx)
            elif mode == Archive7.Delete.SOFT:
                entry = entry._asdict()
                entry['deleted'] = True
                entry['modified'] = datetime.datetime.now()
                entry = Entry(**entry)
                self.ioc.entries.update(entry, idx)
            elif mode == Archive7.Delete.HARD:
                if entry.type == Entry.TYPE_FILE:
                    if not entries.find_blank():
                        entries.make_blanks()
                    bidx = entries.get_blank()
                    entries.update(
                        Entry.empty(
                            offset=entry.offset,
                            size=entries._sector(entry.size)),
                        bidx)
                    entry = entry._asdict()
                    entry['deleted'] = True
                    entry['modified'] = datetime.datetime.now()
                    entry['size'] = 0
                    entry['length'] = 0
                    entry['offset'] = 0
                    entry = Entry(**entry)
                    self.ioc.entries.update(entry, idx)
                elif entry.type in (Entry.TYPE_DIR, Entry.TYPE_LINK):
                    entry = entry._asdict()
                    entry['deleted'] = True
                    entry['modified'] = datetime.datetime.now()
                    entry = Entry(**entry)
                    self.ioc.entries.update(entry, idx)
            else:
                raise Util.exception(Error.AR7_INVALID_DELMODE, {
                    'mode': self.__delete})

    def rename(self, path, dest):
        with self.__lock:
            ops = self.ioc.operations
            entries = self.ioc.entries

            name, dirname = ops.path(path)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)
            ops.is_available(dest, pid)

            entry = entry._asdict()
            entry['name'] = bytes(dest, 'utf-8')
            entry = Entry(**entry)
            entries.update(entry, idx)

    def mkdir(self, path):
        """
        Make a new directory in the archive hierarchy.
            name        The full path and name of new directory
            returns     the entry ID
        """
        with self.__lock:
            paths = self.ioc.hierarchy.paths
            # If path already exists return id
            if path in paths.keys():
                return paths[path]

            # separate new dir name and path to
            dirname = os.path.dirname(path)
            name = os.path.basename(path)

            # Check if path has an ID or is on root level
            if len(dirname):
                if dirname in paths.keys():
                    pid = paths[dirname]
                else:
                    raise Util.exception(
                        Error.AR7_PATH_INVALID, {'path': path})
            else:
                pid = None

            # Generate entry for new directory
            entry = Entry.dir(name=name, parent=pid)
            self.ioc.entries.add(entry)

        return entry.id

    def mkfile(self, filename, data, created=None, modified=None, owner=None,
               parent=None, id=None, compression=Entry.COMP_NONE):
        with self.__lock:
            ops = self.ioc.operations
            name, dirname = ops.path(filename)
            pid = None

            if parent:
                ids = self.ioc.hierarchy.ids
                if parent not in ids.keys():
                    raise Util.exception(Error.AR7_PATH_INVALID, {
                        'parent': parent})
            elif dirname:
                pid = ops.get_pid(dirname)

            ops.is_available(name, pid)

            length = len(data)
            digest = hashlib.sha1(data).digest()
            if compression:
                data = ops.zip(data, compression)
            size = len(data)

            entry = Entry.file(
                name=name, size=size, offset=0, digest=digest,
                id=id, parent=pid, owner=owner, created=created,
                modified=modified, length=length, compression=compression)

        return self.ioc.entries.add(entry, data)

    def link(self, path, link, created=None, modified=None):
        with self.__lock:
            ops = self.ioc.operations
            name, dirname = ops.path(path)
            pid = ops.get_pid(dirname)
            ops.is_available(name, pid)

            lname, ldir = ops.path(link)
            lpid = ops.get_pid(ldir)
            target, tidx = ops.find_entry(lname, lpid)

            if target.type == Entry.TYPE_LINK:
                raise Util.exception(Error.AR7_LINK_2_LINK, {
                    'path': path, 'link': target})

            entry = Entry.link(
                name=name, link=target.id, parent=pid, created=created,
                modified=modified)

        return self.ioc.entries.add(entry)

    def save(self, path, data, compression=Entry.COMP_NONE, modified=None):
        if not modified:
            modified = datetime.datetime.now()

        with self.__lock:
            ops = self.ioc.operations
            entries = self.ioc.entries

            if not entries.find_blank():
                entries.make_blanks()

            name, dirname = ops.path(path)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(
                name, pid, (Entry.TYPE_FILE, Entry.TYPE_LINK))

            if entry.type == Entry.TYPE_LINK:
                entry, idx = ops.follow_link(entry)

            length = len(data)
            digest = hashlib.sha1(data).digest()
            if compression:
                data = ops.zip(data, compression)
            size = len(data)

            osize = entries._sector(entry.size)
            nsize = entries._sector(size)

            if osize < nsize:
                empty = Entry.empty(offset=entry.offset, size=osize)
                last = entries.get_entry(entries.get_thithermost())
                new_offset = entries._sector(last.offset+last.size)
                ops.write_data(new_offset, data + ops.filler(data))

                entry = entry._asdict()
                entry['digest'] = digest
                entry['offset'] = new_offset
                entry['size'] = size
                entry['length'] = length
                entry['modified'] = modified
                entry['compression'] = compression
                entry = Entry(**entry)
                entries.update(entry, idx)

                bidx = entries.get_blank()
                entries.update(empty, bidx)
            elif osize == nsize:
                ops.write_data(entry.offset, data + ops.filler(data))

                entry = entry._asdict()
                entry['digest'] = digest
                entry['size'] = size
                entry['length'] = length
                entry['modified'] = modified
                entry['compression'] = compression
                entry = Entry(**entry)
                entries.update(entry, idx)
            elif osize > nsize:
                ops.write_data(entry.offset, data + ops.filler(data))

                entry = entry._asdict()
                entry['digest'] = digest
                entry['size'] = size
                entry['length'] = length
                entry['modified'] = modified
                entry['compression'] = compression
                entry = Entry(**entry)
                entries.update(entry, idx)

                empty = Entry.empty(
                    offset=entries._sector(entry.offset+nsize),
                    size=osize-nsize)
                bidx = entries.get_blank()
                entries.update(empty, bidx)

    def load(self, filename):
        with self.__lock:
            ops = self.ioc.operations
            name, dirname = ops.path(filename)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(
                name, pid, (Entry.TYPE_FILE, Entry.TYPE_LINK))

            if entry.type == Entry.TYPE_LINK:
                entry, idx = ops.follow_link(entry)
                logging.info('Links to: %s' % str(entry.id))

            data = self.ioc.operations.load_data(entry)

            if entry.compression:
                data = ops.unzip(data, entry.compression)

            if entry.digest != hashlib.sha1(data).digest():
                raise Util.exception(Error.AR7_DIGEST_INVALID, {
                    'filename': filename, 'id': entry.id})

            logging.info('Loading file: %s' % filename)
            return data

    class Entries(ContainerAware):
        def __init__(self, ioc, entries):
            ContainerAware.__init__(self, ioc)
            self.reload()

        def reload(self):
            entries = []
            length = struct.calcsize(Entry.FORMAT)
            header = self.ioc.archive.stats()
            fileobj = self.ioc.fileobj
            fileobj.seek(1024)

            for i in range(header.entries):
                entries.append(
                    Entry.deserialize(
                        fileobj.read(length)))

            self.__all = entries
            self.__files = [i for i in range(
                len(entries)) if entries[i].type == Entry.TYPE_FILE]
            self.__links = [i for i in range(
                len(entries)) if entries[i].type == Entry.TYPE_LINK]
            self.__dirs = [i for i in range(
                len(entries)) if entries[i].type == Entry.TYPE_DIR]
            self.__empties = [i for i in range(
                len(entries)) if entries[i].type == Entry.TYPE_EMPTY]
            self.__blanks = [i for i in range(
                len(entries)) if entries[i].type == Entry.TYPE_BLANK]

        def _sector(self, length):
            return int(math.ceil(length/512)*512)

        def get_entry(self, index):
            return self.__all[index]

        def get_empty(self, size):
            """
            Finds the largest empty space block that is large enough.
            Returns entry index or None
            """
            current = None
            current_size = sys.maxsize

            for i in self.__empties:
                if current_size >= self.__all[i].size >= size:
                    current = i
                    current_size = self.__all[i].size

            if isinstance(current, int):
                return current
            else:
                return None

        def get_blank(self):
            """
            Returns a blank entry to use. Don't use this function if you
            intend to not use the entry. Otherwise the hierarchy will become
            corrupt.
            Returns     index or None
            """
            if len(self.__blanks) >= 1:
                return self.__blanks.pop(0)
            else:
                return None

        def find_blank(self, num=1):
            """
            Finds a number of available blank entries in the hierarchy.
            num         number of available blanks requested for
            Returns     number or None
            """
            tot = len(self.__blanks)
            return tot if tot >= num else None

        def _add_blank(self):
            entry = Entry.blank()
            self.__all.append(entry)
            index = self.__all.index(entry)
            self.__blanks.append(index)
            self.ioc.operations.write_entry(entry, index)

        def make_blanks(self, num=8):
            """
            Create more blank entries by allocating more space in the beginning
            of the file.
            num     Number of new blanks
            """
            cnt = 0
            space = 0
            need = max(num, 8) * 256
            length = len(self.__all)*256 + 1024
            hithermost = None
            nempty = None

            while space < need:
                idx = self.get_hithermost()
                if not idx:
                    space = need
                    continue

                hithermost = self.__all[idx]
                if hithermost.type not in [Entry.TYPE_EMPTY, Entry.TYPE_FILE]:
                    raise Util.exception(Error.AR7_BLANK_FAILURE)

                if hithermost.type == Entry.TYPE_EMPTY:
                    empty = hithermost
                if hithermost.type == Entry.TYPE_FILE:
                    empty = self.ioc.operations.move_end(idx)

                total = self._sector(empty.offset+empty.size) - length
                if hithermost.type == Entry.TYPE_EMPTY:
                    if total >= (need + 512):
                        entry = hithermost._asdict()
                        entry['offset'] = self._sector(length + need)
                        entry['size'] = self._sector(total - need)
                        entry = Entry(**entry)
                        self.update(entry, idx)
                        space = need
                    else:
                        self.update(Entry.blank(), idx)
                        space = total

                if hithermost.type == Entry.TYPE_FILE:
                    if total >= (need + 512):
                        entry = empty._asdict()
                        entry['offset'] = self._sector(length + need)
                        entry['size'] = self._sector(total - need)
                        nempty = Entry(**entry)
                        space = need
                    else:
                        space = total

            for _ in range(int(space / 256)):
                self._add_blank()
                cnt += 1

            if nempty:
                bidx = self.get_blank()
                self.update(nempty, bidx)
                cnt -= 1

            self.ioc.archive._update_header(len(self.__all))
            return cnt

        def get_hithermost(self, limit=0):
            idx = None
            offset = sys.maxsize

            idxs = set(self.__files + self.__empties)
            for i in idxs:
                if offset > self.__all[i].offset > limit:
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def get_thithermost(self, limit=sys.maxsize):
            idx = None
            offset = 0

            idxs = set(self.__files + self.__empties)
            for i in idxs:
                if offset < self.__all[i].offset < limit:
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def update(self, entry, index):
            """Updates an entry, saves it and keep hierachy clean."""
            old = self.__all[index]
            if entry.type != old.type:

                # Remove index
                if old.type == Entry.TYPE_FILE:
                    self.__files = [x for x in self.__files if x != index]
                elif old.type == Entry.TYPE_LINK:
                    self.__links = [x for x in self.__links if x != index]
                elif old.type == Entry.TYPE_DIR:
                    self.__dirs = [x for x in self.__dirs if x != index]
                    self.ioc.hierarchy.remove(old)
                elif old.type == Entry.TYPE_BLANK:
                    self.__blanks = [x for x in self.__blanks if x != index]
                elif old.type == Entry.TYPE_EMPTY:
                    self.__empties = [x for x in self.__empties if x != index]
                else:
                    raise OSError('Unknown entry type', old.type)

                # Add index
                if entry.type == Entry.TYPE_FILE:
                    self.__files.append(index)
                elif entry.type == Entry.TYPE_LINK:
                    self.__links.append(index)
                elif entry.type == Entry.TYPE_DIR:
                    self.__dirs.append(index)
                    self.ioc.hierarchy.add(entry)
                elif entry.type == Entry.TYPE_BLANK:
                    self.__blanks.append(index)
                elif entry.type == Entry.TYPE_EMPTY:
                    self.__empties.append(index)
                else:
                    raise OSError('Unknown entry type', entry.type)

            elif entry.type == Entry.TYPE_DIR:
                self.ioc.hierarchy.remove(old)
                self.ioc.hierarchy.add(entry)

            self.__all[index] = entry
            self.ioc.operations.write_entry(entry, index)

        def add(self, entry, data=None):
            if not self.find_blank():
                self.make_blanks()

            if entry.type in [Entry.TYPE_DIR, Entry.TYPE_LINK]:
                bidx = self.get_blank()
                self.update(entry, bidx)

            elif entry.type == Entry.TYPE_FILE:
                if isinstance(data, type(None)) or not len(data):
                    raise Util.exception(Error.AR7_DATA_MISSING, {
                        'id': entry.id})
                space = self._sector(len(data))
                eidx = self.get_empty(space)
                if isinstance(eidx, int):
                    empty = self.__all[eidx]
                    offset = empty.offset
                    if empty.size > space:
                        empty = empty._asdict()
                        empty['offset'] = offset + space
                        empty['size'] = self._sector(empty['size'] - space)
                        empty = Entry(**empty)
                        self.update(empty, eidx)
                    else:
                        self.update(Entry.blank(), eidx)
                elif (len(self.__files) + len(self.__empties)) > 0:
                    last = self.__all[self.get_thithermost()]
                    offset = self._sector(last.offset + last.size)
                else:
                    offset = self._sector(1024 + len(self.__all) * 256)

                entry = entry._asdict()
                entry['offset'] = offset
                entry = Entry(**entry)

                ops = self.ioc.operations
                ops.write_data(offset, data + ops.filler(data))
                bidx = self.get_blank()
                self.update(entry, bidx)
            else:
                raise Util.exception(Error.AR7_WRONG_ENTRY, {
                    'type': entry.type, 'id': entry.id})

        def search(self, query, raw=False):
            Util.is_type(query, Archive7.Query)
            filterator = filter(query.build(
                self.ioc.hierarchy.paths), enumerate(self.__all))
            if not raw:
                return list(filterator)
            else:
                return filterator

        def follow(self, entry):
            if entry.type != Entry.TYPE_LINK:
                raise Util.exception(Error.AR7_WRONG_ENTRY, {
                    'type': entry.type, 'id': entry.id})
            query = Archive7.Query().id(entry.owner)
            return list(filter(query.build(), enumerate(self.__all)))

        @property
        def count(self):
            return len(self.__all)

        @property
        def files(self):
            return self.__files

        @property
        def links(self):
            return self.__links

        @property
        def dirs(self):
            return self.__dirs

        @property
        def empties(self):
            return self.__empties

        @property
        def blanks(self):
            return self.__blanks

    class Hierarchy(ContainerAware):
        def __init__(self, ioc):
            ContainerAware.__init__(self, ioc)
            self.reload()

        def _build(self):
            pass

        def reload(self, deleted=False):
            entries = self.ioc.entries
            dirs = entries.dirs
            zero = uuid.UUID(bytes=b'\x00'*16)
            self.__paths = {'/': zero}
            self.__ids = {zero: '/'}

            for i in range(len(dirs)):
                path = []
                search_path = ''
                current = entries.get_entry(dirs[i])
                cid = current.id
                path.append(current)

                if not deleted and current.deleted is True:
                    break

                while current.parent.int != zero.int:
                    parent = None
                    for i in range(len(dirs)):
                        entry = entries.get_entry(dirs[i])
                        if entry.id.int == current.parent.int:
                            parent = entry
                            break

                    if not parent:
                        raise Util.exception(Error.AR7_PATH_BROKEN, {
                            'id': current.id})

                    current = parent
                    path.append(current)

                search_path = ''
                path.reverse()
                for j in range(len(path)):
                    search_path += '/' + str(path[j].name, 'utf-8')

                self.__paths[search_path] = cid
                self.__ids[cid] = search_path

        def add(self, entry, deleted=False):
            entries = self.ioc.entries
            dirs = entries.dirs
            path = []
            current = entry
            cid = current.id
            path.append(current)

            if not deleted and current.deleted is True:
                return

            while current.parent.int != 0:
                parent = None
                for i in range(len(dirs)):
                    entry = entries.get_entry(dirs[i])
                    if entry.id.int == current.parent.int:
                        parent = entry
                        break

                if not parent:
                    raise Util.exception(Error.AR7_PATH_BROKEN, {
                        'id': current.id})

                current = parent
                path.append(current)

            search_path = ''
            path.reverse()
            for j in range(len(path)):
                search_path += '/' + str(path[j].name, 'utf-8')

            self.__paths[search_path] = cid
            self.__ids[cid] = search_path

        def remove(self, entry):
            path = self.__ids[entry.id]
            del self.__paths[path]
            del self.__ids[entry.id]

        @property
        def paths(self):
            return self.__paths

        @property
        def ids(self):
            return self.__ids

    class Operations(ContainerAware):
        def filler(self, data):
            length = len(data)
            return b'\x00' * (int(math.ceil(length/512)*512) - length)

        def path(self, path):
            return os.path.basename(path), os.path.dirname(path)

        def get_pid(self, dirname):
            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise Util.exception(Error.AR7_INVALID_DIR, {
                    'dirname': dirname})
            return paths[dirname]

        def follow_link(self, entry):
            idxs = self.ioc.entries.follow(entry)
            if not len(idxs):
                raise Util.exception(Error.AR7_LINK_BROKEN, {'id': entry.id})
            else:
                idx, link = idxs.pop(0)
                if link.type != Entry.TYPE_FILE:
                    raise Util.exception(Error.AR7_WRONG_ENTRY, {
                        'id': entry.id, 'link': link.id})
            return link, idx

        def find_entry(self, name, pid, types=None):
            entries = self.ioc.entries
            idx = entries.search(
                Archive7.Query(pattern=name).parent(pid).type(
                    types).deleted(False))
            if not len(idx):
                raise Util.exception(Error.AR7_INVALID_FILE, {
                    'name': name, 'pid': pid})
            else:
                idx, entry = idx.pop(0)
            return entry, idx

        def write_entry(self, entry, index):
            Util.is_type(entry, Entry)
            Util.is_type(index, int)

            offset = index * 256 + 1024
            fileobj = self.ioc.fileobj
            if offset != fileobj.seek(offset):
                raise Util.exception(Error.AR7_INVALID_SEEK, {
                    'position': offset})

            fileobj.write(entry.serialize())

        def load_data(self, entry):
            if entry.type != Entry.TYPE_FILE:
                raise Util.exception(Error.AR7_WRONG_ENTRY, {
                    'type': entry.type, 'id': entry.id})
            fileobj = self.ioc.fileobj
            if fileobj.seek(entry.offset) != entry.offset:
                raise Util.exception(Error.AR7_INVALID_SEEK, {
                    'position': entry.offset})
            return fileobj.read(entry.size)

        def write_data(self, offset, data):
            fileobj = self.ioc.fileobj
            if fileobj.seek(offset) != offset:
                raise Util.exception(Error.AR7_INVALID_SEEK, {
                    'position': offset})
            fileobj.write(data)

        def move_end(self, idx):
            """
            Copy data for a file to the end of the archive
            idx         Index of entry
            returns     Non-registered empty entry
            """
            entries = self.ioc.entries
            entry = entries.get_entry(idx)
            if not entry.type == Entry.TYPE_FILE:
                raise Util.exception(Error.AR7_WRONG_ENTRY, {
                    'type': entry.type, 'id': entry.id})

            last = entries.get_entry(entries.get_thithermost())
            data = self.load_data(entry)
            noffset = entries._sector(last.offset+last.size)
            self.write_data(noffset, data + self.filler(data))
            empty = Entry.empty(entry.offset, entries._sector(entry.size))

            entry = entry._asdict()
            entry['offset'] = noffset
            entry = Entry(**entry)
            entries.update(entry, idx)

            return empty

        def check(self, entry, data):
            return entry.digest == hashlib.sha1(data).digest()

        def is_available(self, name, pid):
            idx = self.ioc.entries.search(
                Archive7.Query(pattern=name).parent(pid).deleted(False))
            if len(idx):
                raise Util.exception(Error.AR7_NAME_TAKEN, {
                    'name': name, 'pid': pid, 'index': idx})
            return True

        def zip(self, data, compression):
            if compression == Entry.COMP_ZIP:
                return zlib.compress(data)
            elif compression == Entry.COMP_GZIP:
                return gzip.compress(data)
            elif compression == Entry.COMP_BZIP2:
                return bz2.compress(data)
            else:
                raise Util.exception(Error.AR7_INVALID_COMPRESSION, {
                    'compression': compression})

        def unzip(self, data, compression):
            if compression == Entry.COMP_ZIP:
                return zlib.decompress(data)
            elif compression == Entry.COMP_GZIP:
                return gzip.decompress(data)
            elif compression == Entry.COMP_BZIP2:
                return bz2.decompress(data)
            else:
                raise Util.exception(Error.AR7_INVALID_COMPRESSION, {
                    'compression': compression})

        def vacuum(self):
            entries = self.ioc.entries
            all = entries.dirs + entries.files + entries.links
            cnt = len(all)

            if cnt != len(set(all)):
                raise Util.exception(Error.AR7_ENTRIES_CORRUPT)

            self.ioc.archive._update_header(self.ioc.entries.count)

            for i in range(len(all)):
                self.write_entry(entries.get_entry(all[i]), i)

            entries.reload()
            self.ioc.hierarchy.reload()

            offset = entries._sector(cnt * 256 + 1024)
            hidx = entries.get_hithermost(offset)
            while(hidx):
                entry = entries.get_entry(hidx)
                data = self.load_data(entry)
                self.write_data(offset, data + self.filler(data))

                entry = entry._asdict()
                entry['offset'] = offset
                entry = Entry(**entry)
                entries.update(entry, hidx)

                offset = entries._sector(offset + entry.size)
                hidx = entries.get_hithermost(offset)

            self.ioc.fileobj.truncate(offset)

    class Query:
        EQ = '='
        NE = '≠'
        GT = '>'
        LT = '<'

        def __init__(self, pattern='*'):
            self.__type = (Entry.TYPE_FILE, Entry.TYPE_DIR, Entry.TYPE_LINK)
            if pattern == '*':
                self.__file_regex = None
                self.__dir_regex = None
            else:
                filename = re.escape(os.path.basename(
                    pattern)).replace('\*', '.*').replace('\?', '.')
                dirname = re.escape(os.path.dirname(
                    pattern)).replace('\*', '.*').replace('\?', '.')
                self.__file_regex = re.compile(bytes(filename, 'utf-8'))
                self.__dir_regex = re.compile(dirname)
            self.__id = None
            self.__parent = None
            self.__owner = None
            self.__created = None
            self.__modified = None
            self.__deleted = None

        @property
        def types(self):
            return self.__type

        def type(self, _type=None, operand='='):
            Util.is_type(_type, (tuple, bytes, type(None)))
            if isinstance(_type, tuple):
                self.__type = _type
            elif isinstance(_type, bytes):
                self.__type = (_type, )
            return self

        def id(self, id=None):
            Util.is_type(id, uuid.UUID)
            self.__id = id
            return self

        def parent(self, parent, operand='='):
            Util.is_type(parent, (uuid.UUID, tuple, type(None)))
            if operand not in ['=', '≠']:
                raise Util.exception(Error.AR7_OPERAND_INVALID, {
                    'operand': operand})
            if isinstance(parent, uuid.UUID):
                self.__parent = ([parent.int], operand)
            elif isinstance(parent, tuple):
                ints = []
                for i in parent:
                    ints.append(i.int)
                self.__parent = (ints, operand)
            return self

        def owner(self, owner, operand='='):
            Util.is_type(owner, (uuid.UUID, tuple, type(None)))
            if operand not in ['=', '≠']:
                raise Util.exception(Error.AR7_OPERAND_INVALID, {
                    'operand': operand})
            if isinstance(owner, uuid.UUID):
                self.__owner = ([owner.int], operand)
            elif isinstance(owner, tuple):
                ints = []
                for i in owner:
                    ints.append(i.int)
                self.__owner = (ints, operand)
            return self

        def created(self, created, operand='>'):
            Util.is_type(created, (int, str, datetime.datetime))
            if operand not in ['=', '>', '<']:
                raise Util.exception(Error.AR7_OPERAND_INVALID, {
                    'operand': operand})
            if isinstance(created, int):
                created = datetime.datetime.fromtimestamp(created)
            elif isinstance(created, str):
                created = datetime.datetime.fromisoformat(created)
            self.__created = (created, operand)
            return self

        def modified(self, modified, operand='>'):
            Util.is_type(modified, (int, str, datetime.datetime))
            if operand not in ['=', '>', '<']:
                raise Util.exception(Error.AR7_OPERAND_INVALID, {
                    'operand': operand})
            if isinstance(modified, int):
                modified = datetime.datetime.fromtimestamp(modified)
            elif isinstance(modified, str):
                modified = datetime.datetime.fromisoformat(modified)
            self.__modified = (modified, operand)
            return self

        def deleted(self, deleted):
            Util.is_type(deleted, bool)
            self.__deleted = deleted
            return self

        def build(self, paths=None):
            if self.__dir_regex and paths:
                parents = []
                for key, value in paths.items():
                    if bool(self.__dir_regex.match(key)):
                        parents.append(value)
                self.parent(tuple(parents))

            def _type_in(x):
                return x.type in self.__type

            def _name_match(x):
                return bool(self.__file_regex.match(x.name))

            def _id_is(x):
                return self.__id.int == x.id.int

            def _parent_is(x):
                return x.parent.int in self.__parent[0]

            def _parent_not(x):
                return x.parent.int not in self.__parent[0]

            def _owner_is(x):
                return x.owner.int in self.__owner[0]

            def _owner_not(x):
                return x.owner.int not in self.__owner[0]

            def _created_eq(x):
                return x.created == self.__created[0]

            def _created_lt(x):
                return x.created > self.__created[0]

            def _created_gt(x):
                return x.created < self.__created[0]

            def _modified_eq(x):
                return x.modified == self.__modified[0]

            def _modified_lt(x):
                return x.modified > self.__modified[0]

            def _modified_gt(x):
                return x.modified < self.__modified[0]

            def _deleted_is(x):
                return x.deleted is True

            def _deleted_not(x):
                return x.deleted is False

            qualifiers = [_type_in]

            if self.__file_regex:
                qualifiers.append(_name_match)
            if self.__id:
                qualifiers.append(_id_is)
            if self.__parent:
                if self.__parent[1] == '=':
                    qualifiers.append(_parent_is)
                elif self.__parent[1] == '≠':
                    qualifiers.append(_parent_not)
            if self.__owner:
                if self.__owner[1] == '=':
                    qualifiers.append(_owner_is)
                elif self.__owner[1] == '≠':
                    qualifiers.append(_owner_not)
            if self.__created:
                if self.__created[1] == '=':
                    qualifiers.append(_created_eq)
                elif self.__created[1] == '<':
                    qualifiers.append(_created_lt)
                elif self.__created[1] == '>':
                    qualifiers.append(_created_gt)
            if self.__modified:
                if self.__modified[1] == '=':
                    qualifiers.append(_modified_eq)
                elif self.__modified[1] == '<':
                    qualifiers.append(_modified_lt)
                elif self.__modified[1] == '>':
                    qualifiers.append(_modified_gt)
            if isinstance(self.__deleted, bool):
                if self.__deleted:
                    qualifiers.append(_deleted_is)
                else:
                    qualifiers.append(_deleted_not)

            def query(x):
                for q in qualifiers:
                    if not q(x[1]):
                        return False
                return True

            return query

    class Delete(enum.IntEnum):
        SOFT = 1  # Raise file delete flag
        HARD = 2  # Raise  file delete flag, set size and offset to zero, add empty block.  # noqa #E501
        ERASE = 3  # Replace file with empty block

    def __del__(self):
        self.close()
