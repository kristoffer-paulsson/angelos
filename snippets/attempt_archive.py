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
import random
import string
import types


class Container:
    """Docstring"""
    def __init__(self, config={}):
        """Docstring"""
        if not isinstance(config, dict): raise TypeError()  # noqa E501

        self.__config = config
        self.__instances = {}

    def __getattr__(self, name):
        """Docstring"""
        if name not in self.__instances:
            if name not in self.__config:
                raise IndexError()
            elif isinstance(self.__config[name], types.LambdaType):
                self.__instances[name] = self.__config[name](self)
            else:
                raise TypeError()
        return self.__instances[name]


class ContainerAware:
    def __init__(self, ioc):
        self.__ioc = ioc

    @property
    def ioc(self):
        return self.__ioc


class Header(collections.namedtuple('Header', field_names=[
    'major',        # 2
    'minor',        # 2
    'type',         # 1
    'role',         # 1
    'use',          # 1
    'id',           # 16
    'owner',        # 16
    'network',      # 16
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
    def header(owner, id=None, node=None, network=None, title=None, _type=None,
               role=None, use=None, major=1, minor=0, entries=8):
        if not isinstance(owner, uuid.UUID): raise TypeError()  # noqa E701
        if not isinstance(id, (uuid.UUID, type(None))): raise TypeError()  # noqa E701
        if not isinstance(node, (uuid.UUID, type(None))): raise TypeError()  # noqa E701
        if not isinstance(network, (uuid.UUID, type(None))): raise TypeError()  # noqa E701
        if not isinstance(title, (bytes, bytearray, type(None))): raise TypeError()  # noqa E701
        if not isinstance(_type, (int, type(None))): raise TypeError()  # noqa E701
        if not isinstance(role, (int, type(None))): raise TypeError()  # noqa E701
        if not isinstance(use, (int, type(None))): raise TypeError()  # noqa E701
        if not isinstance(major, int): raise TypeError()  # noqa E701
        if not isinstance(minor, int): raise TypeError()  # noqa E701
        if not isinstance(entries, int): raise TypeError()  # noqa E701

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
            network=network,
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
            self.network.bytes if isinstance(
                self.network, uuid.UUID) else b'\x00'*16,
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
        if not isinstance(data, (bytes, bytearray)): raise TypeError()  # noqa E701
        t = struct.unpack(Header.FORMAT, data)

        if t[0] != b'archive7':
            raise OSError()

        return Header(
            major=t[1],
            minor=t[2],
            type=t[3],
            role=t[4],
            use=t[5],
            id=uuid.UUID(bytes=t[6]),
            owner=uuid.UUID(bytes=t[7]),
            network=uuid.UUID(bytes=t[8]),
            node=uuid.UUID(bytes=t[9]),
            created=datetime.datetime.fromtimestamp(t[10]),
            title=t[11],
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
        if not isinstance(offset, int): raise TypeError()  # noqa E701
        if not isinstance(size, int): raise TypeError()  # noqa E701

        kwargs = {
            'type': Entry.TYPE_EMPTY,
            'id': uuid.uuid4(),
            'offset': offset,
            'size': size,
        }
        return Entry(**kwargs)

    @staticmethod
    def dir(name, parent=None, owner=None, created=None, modified=None):
        if not isinstance(name, str): raise TypeError()  # noqa E701
        if not isinstance(parent, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(owner, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(created, (type(None), datetime.datetime)): raise TypeError()  # noqa E701
        if not isinstance(modified, (type(None), datetime.datetime)): raise TypeError()  # noqa E701

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
        if not isinstance(name, str): raise TypeError()  # noqa E701
        if not isinstance(parent, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(link, uuid.UUID): raise TypeError()  # noqa E701
        if not isinstance(created, (type(None), datetime.datetime)): raise TypeError()  # noqa E701
        if not isinstance(modified, (type(None), datetime.datetime)): raise TypeError()  # noqa E701

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
        if not isinstance(name, str): raise TypeError()  # noqa E701
        if not isinstance(offset, int): raise TypeError()  # noqa E701
        if not isinstance(size, int): raise TypeError()  # noqa E701
        if not isinstance(digest, bytes): raise TypeError()  # noqa E701
        if not isinstance(id, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(parent, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(owner, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(created, (type(None), datetime.datetime)): raise TypeError()  # noqa E701
        if not isinstance(modified, (type(None), datetime.datetime)): raise TypeError()  # noqa E701
        if not isinstance(compression, (type(None), int)): raise TypeError()  # noqa E701
        if not isinstance(length, (type(None), int)): raise TypeError()  # noqa E701

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
                raise ValueError()
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
        if not isinstance(data, (bytes, bytearray)): raise TypeError()  # noqa E701
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
            name=t[12]
        )


class Archive(ContainerAware):
    BLOCK_SIZE = 512

    def __init__(self, fileobj):
        self.__closed = False
        self.__lock = threading.Lock()
        self.__file = fileobj
        self.__header = None
        self.__size = os.path.getsize(self.__file.name)
        self.__delete = Archive.Delete.ERASE

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
            'entries': lambda s: Archive.Entries(s, entries),
            'hierarchy': lambda s: Archive.Hierarchy(s),
            'operations': lambda s: Archive.Operations(s),
            'fileobj': lambda s: self.__file
        }))

    @property
    def closed(self):
        return self.__closed

    def _update_header(self, cnt):
        header = self.__header._asdict()
        header['entries'] = cnt
        self.__header = Header(**header)
        self.ioc.operations.write_data(0, self.__header.serialize())

    @staticmethod
    def create(path, owner, node=None, title=None,
               network=None, _type=None, role=None, use=None):
        if not os.path.isfile(path):
            open(path, 'a').close()

        fileobj = open(path, 'rb+')
        header = Header.header(
            owner=owner, node=node, title=title,
            network=network, _type=_type, role=role, use=use)

        fileobj.write(header.serialize())
        for i in range(header.entries):
            fileobj.write(Entry.blank().serialize())
        fileobj.seek(0)

        return Archive(fileobj)

    @staticmethod
    def open(path):
        if not os.path.isfile(path):
            raise FileNotFoundError()

        fileobj = open(path, 'rb+')
        return Archive(fileobj)

    def close(self):
        with self.__lock:
            if not self.__closed:
                self.__file.close()

    def stats(self):
        pass

    def info(self, name):
        pass

    def glob(self, name='*', id=None, parent=None,
             owner=None, created=None, modified=None, deleted=None):
        with self.__lock:
            entries = self.ioc.entries
            ids = self.ioc.hierarchy.ids

            sq = Archive.Query(name=name)
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

    def move(self, name, dest):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise OSError('Directory not found.')
            pid = paths[dirname]

            if dest not in paths.keys():
                raise OSError('Target directory not found.')
            did = paths[dest]

            entries = self.ioc.entries
            midx = entries.search(
                Archive.Query(name=name).parent(pid))
            if not len(midx):
                raise OSError('File not found in directory.')
            else:
                midx, entry = midx.pop(0)

            tidx = entries.search(
                Archive.Query(name=name).parent(did))
            if len(tidx):
                raise OSError('Name taken in target directory.')

            entry = entry._asdict()
            entry['parent'] = did
            entry = Entry(**entry)
            entries.update(entry, midx)

    def chmod(self, name, id=None, owner=None, deleted=None, compression=None):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise OSError('Directory not found.')
            pid = paths[dirname]

            entries = self.ioc.entries
            chidx = entries.search(
                Archive.Query(name=name).parent(pid))
            if not len(chidx):
                raise OSError('File not found in directory.')
            else:
                chidx, entry = chidx.pop(0)

            entry = entry._asdict()
            if id:
                entry['id'] = id
            if owner:
                entry['owner'] = owner
            if deleted:
                entry['deleted'] = deleted
            entry = Entry(**entry)
            entries.update(entry, chidx)

    def remove(self, name, mode=None):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise OSError('Directory not found.')
            pid = paths[dirname]

            entries = self.ioc.entries
            ridx = entries.search(
                Archive.Query(name=name).parent(pid))
            if not len(ridx):
                raise OSError('File not found in directory.')
            else:
                ridx, entry = ridx.pop(0)

            if entry.type is Entry.TYPE_FILE:
                entries.update(
                    Entry.empty(
                        offset=entry.offset,
                        size=entries._sector(entry.size)),
                    ridx)
            elif entry.type is Entry.TYPE_DIR:
                cidx = entries.search(
                    Archive.Query().parent(entry.id))
                if len(cidx):
                    raise OSError('Directory not empty.')
                entries.update(Entry.blank(), ridx)
            else:
                raise OSError('Unkown entry type.')

    def rename(self, name, dest):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise OSError('Directory not found.')
            pid = paths[dirname]

            entries = self.ioc.entries
            oidx = entries.search(
                Archive.Query(name=name).parent(pid))
            if not len(oidx):
                raise OSError('File not found in directory.')
            else:
                oidx, entry = oidx.pop(0)

            didx = entries.search(
                Archive.Query(name=dest).parent(pid))
            if len(didx):
                raise OSError('File name already taken in directory.')

            entry = entry._asdict()
            entry['name'] = bytes(dest, 'utf-8')
            entry = Entry(**entry)
            entries.update(entry, oidx)

    def mkdir(self, name):
        """
        Make a new directory in the archive hierarchy.
            name        The full path and name of new directory
            returns     the entry ID
        """
        with self.__lock:
            paths = self.ioc.hierarchy.paths
            # If path already exists return id
            if name in paths.keys():
                return paths[name]

            # separate new dir name and path to
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            # Check if path has an ID or is on root level
            if len(dirname):
                if dirname in paths.keys():
                    pid = paths[dirname]
                else:
                    raise OSError('Path doesn\'t exist.', dirname)
            else:
                pid = None

            # Generate entry for new directory
            entry = Entry.dir(name=name, parent=pid)
            self.ioc.entries.add(entry)

        return entry.id

    def mkfile(self, name, data, created=None, modified=None, owner=None,
               parent=None, id=None, compression=Entry.COMP_NONE):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)
            pid = None

            if parent:
                ids = self.ioc.hierarchy.ids
                if parent not in ids.keys():
                    raise OSError('Parent folder doesn\'t exist')
            elif dirname:
                paths = self.ioc.hierarchy.paths
                if dirname in paths.keys():
                    pid = paths[dirname]

            didx = self.ioc.entries.search(
                Archive.Query(name=name).parent(pid))
            if len(didx):
                raise OSError('File name already taken in directory.')

            entry = Entry.file(
                name=name, size=len(data), offset=0,
                digest=hashlib.sha1(data).digest(),
                id=id, parent=pid, owner=owner, created=created,
                modified=modified, length=len(data))

        return self.ioc.entries.add(entry, data)

    def link(self, name, link, created=None, modified=None):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise OSError('Directory not found.')
            pid = paths[dirname]

            entries = self.ioc.entries
            didx = entries.search(
                Archive.Query(name=name).parent(pid))
            if len(didx):
                raise OSError('File name already taken in directory.')

            ldir = os.path.dirname(link)
            lname = os.path.basename(link)
            if ldir not in paths.keys():
                raise OSError('Link directory not found.')
            lpid = paths[ldir]
            lidx = entries.search(
                Archive.Query(name=lname).parent(lpid))
            if not len(lidx):
                raise OSError('Link file not found in directory.')
            else:
                lidx, linked = lidx.pop(0)[0]

            if linked.type == Entry.TYPE_LINK:
                raise OSError('You can not link to a link')

            entry = Entry.link(
                name=name, link=linked.id, parent=pid, created=created,
                modified=modified)

        return self.ioc.entries.add(entry)

    def save(self, name, data):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise OSError('Directory not found.')
            pid = paths[dirname]

            entries = self.ioc.entries
            sidx = entries.search(
                Archive.Query(name=name).parent(pid).type(
                    (Entry.TYPE_FILE, Entry.TYPE_LINK)))
            if not len(sidx):
                raise OSError('File not found in directory.')
            else:
                sidx, entry = sidx.pop(0)

            osize = entries._sector(entry.size)
            nsize = entries._sector(len(data))

            if osize < nsize:
                empty = Entry.empty(offset=entry.offset, size=osize)
                last = entries.get_entry(entries.get_thithermost())
                new_offset = entries._sector(last.offset+last.size)
                self.ioc.operations.write_data(new_offset, data)

                entry = entry._asdict()
                entry['digest'] = hashlib.sha1(data).digest()
                entry['offset'] = new_offset
                entry['size'] = len(data)
                entry['modified'] = datetime.datetime.now()
                entry = Entry(**entry)
                entries.update(entry, sidx)

                if not entries.find_blank():
                    entries.make_blanks()
                bidx = entries.get_blank()
                entries.update(empty, bidx)
            elif osize == nsize:
                self.ioc.operations.write_data(entry.offset, data)

                entry = entry._asdict()
                entry['digest'] = hashlib.sha1(data).digest()
                entry['size'] = len(data)
                entry['modified'] = datetime.datetime.now()
                entry = Entry(**entry)
                entries.update(entry, sidx)
            elif osize > nsize:
                self.ioc.operations.write_data(entry.offset, data)

                entry = entry._asdict()
                entry['digest'] = hashlib.sha1(data).digest()
                entry['size'] = len(data)
                entry['modified'] = datetime.datetime.now()
                entry = Entry(**entry)
                entries.update(entry, sidx)

                empty = Entry.empty(
                    offset=entry.offset+nsize, size=osize-nsize)
                if not entries.find_blank():
                    entries.make_blanks()
                bidx = entries.get_blank()
                entries.update(empty, bidx)

    def load(self, name):
        with self.__lock:
            dirname = os.path.dirname(name)
            name = os.path.basename(name)

            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise OSError('Directory not found.')
            pid = paths[dirname]

            entries = self.ioc.entries
            lidx = entries.search(
                Archive.Query(name=name).parent(pid).type(
                    (Entry.TYPE_FILE, Entry.TYPE_LINK)))
            if not len(lidx):
                raise OSError('File not found in directory.')
            else:
                lidx, entry = lidx.pop(0)

            data = self.ioc.operations.load_data(entry)
            if entry.digest != hashlib.sha1(data).digest():
                raise OSError('Hash digest doesn\'t match. File is corrupt.')
            return data

    class Entries(ContainerAware):
        def __init__(self, ioc, entries):
            ContainerAware.__init__(self, ioc)
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

        def make_blanks(self):
            """
            Create more blank entries by allocating more space in the beginning
            of the file.
            num     Number of new blanks
            """
            cnt = 0
            idx = self.get_hithermost()
            if not idx:
                for i in range(8):
                    self._add_blank()
                    cnt += 1
            else:
                hithermost = self.__all[idx]
                length = len(self.__all)*256 + 1024
                space = self._sector(hithermost.offset - length)

                if space:
                    # If there is enoigh space in between, us it!
                    for _ in range(int(space / 256)):
                        self._add_blank()
                        cnt += 1
                elif hithermost.type == Entry.TYPE_EMPTY:
                    # If empty, use parts of it!
                    space = self._sector(
                        hithermost.offset + hithermost.size - length)
                    num = int(space / 256)
                    for _ in range(min(8, num)):
                        self._add_blank()
                        cnt += 1
                    if num > cnt:  # If not full, resize and sava empty
                        entry = hithermost._asdict()
                        entry['offset'] = self._sector(
                            (num - cnt) * 256 + entry['offset'])
                        entry['size'] = self._sector((num - cnt) * 256)
                        entry = Entry(**entry)
                        self.update(entry, idx)
                    else:  # If full save blank
                        self.update(Entry.blank(), idx)
                        cnt += 1
                elif hithermost.type == Entry.TYPE_FILE:
                    # If file, move and fill!
                    empty = self.ioc.operations.move_end(idx)
                    space = self._sector(
                        empty.offset + empty.size - length)
                    num = int(space / 256)
                    for _ in range(min(8, num)):
                        self._add_blank()
                        cnt += 1
                    if num > cnt:  # If not full, save new empty
                        entry = empty._asdict()
                        entry['offset'] = self._sector(
                            (num - cnt) * 256 + entry['offset'])
                        entry['size'] = self._sector((num - cnt) * 256)
                        entry = Entry(**entry)
                        bidx = self.get_blank()
                        self.update(entry, bidx)
                        cnt -= 1

            if not cnt:
                raise OSError('Failed making blank entries.')

            return cnt

        def get_hithermost(self):
            idx = None
            offset = sys.maxsize

            idxs = set(self.__files + self.__empties)
            for i in idxs:
                if offset > self.__all[i].offset > 0:
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def get_thithermost(self):
            idx = None
            offset = 0

            idxs = set(self.__files + self.__empties)
            for i in idxs:
                if offset < self.__all[i].offset < sys.maxsize:
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def update(self, entry, index):
            """Updates an entry, saves it and keep hierachy clean."""
            old = self.__all[index]
            if entry.type is not old.type:

                # Remove index
                if old.type is Entry.TYPE_FILE:
                    self.__files = [x for x in self.__files if x != index]
                elif old.type is Entry.TYPE_LINK:
                    self.__links = [x for x in self.__links if x != index]
                elif old.type is Entry.TYPE_DIR:
                    self.__dirs = [x for x in self.__dirs if x != index]
                    self.ioc.hierarchy.remove(old)
                elif old.type is Entry.TYPE_BLANK:
                    self.__blanks = [x for x in self.__blanks if x != index]
                elif old.type is Entry.TYPE_EMPTY:
                    self.__empties = [x for x in self.__empties if x != index]
                else:
                    OSError('Unknown entry type', old.type)

                # Add index
                if entry.type is Entry.TYPE_FILE:
                    self.__files.append(index)
                elif entry.type is Entry.TYPE_LINK:
                    self.__links.append(index)
                elif entry.type is Entry.TYPE_DIR:
                    self.__dirs.append(index)
                    self.ioc.hierarchy.add(entry)
                elif entry.type is Entry.TYPE_BLANK:
                    self.__blanks.append(index)
                elif entry.type is Entry.TYPE_EMPTY:
                    self.__empties.append(index)
                else:
                    OSError('Unknown entry type', entry.type)

            elif entry.type == Entry.TYPE_DIR:
                self.ioc.hierarchy.remove(old)
                self.ioc.hierarchy.add(entry)

            self.__all[index] = entry
            self.ioc.operations.write_entry(entry, index)

        def add(self, entry, data=None):
            if entry.type in [Entry.TYPE_DIR, Entry.TYPE_LINK]:
                if not len(self.__blanks):
                    self.make_blanks()
                bidx = self.get_blank()
                self.update(entry, bidx)

            elif entry.type == Entry.TYPE_FILE:
                if isinstance(data, type(None)) or not len(data):
                    raise OSError('No file data.')
                if not len(self.__blanks):
                    self.make_blanks()
                bidx = self.get_blank()
                space = self._sector(len(data))
                eidx = self.get_empty(space)
                if isinstance(eidx, int):
                    empty = self.__all[eidx]
                    offset = empty.offset
                    if empty.size > space:
                        empty = empty._asdict()
                        empty['offset'] = offset + space
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

                self.ioc.operations.write_data(offset, data)
                self.update(entry, bidx)

            else:
                raise ValueError('Unkown entry type.', entry.type)

        def search(self, query):
            if not isinstance(
                query, Archive.Query): raise TypeError()  # noqa E501
            qfilter = query.build()
            return list(filter(qfilter, enumerate(self.__all)))

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

        def reload(self):
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

                while current.parent.int != zero.int:
                    parent = None
                    for i in range(len(dirs)):
                        entry = entries.get_entry(dirs[i])
                        if entry.id.int == current.parent.int:
                            parent = entry
                            break

                    if not parent:
                        raise RuntimeError(
                            'Directory doesn\'t reach root!', current)

                    current = parent
                    path.append(current)

                search_path = ''
                path.reverse()
                for j in range(len(path)):
                    search_path += '/' + str(path[j].name, 'utf-8')

                self.__paths[search_path] = cid
                self.__ids[cid] = search_path

        def add(self, entry):
            entries = self.ioc.entries
            dirs = entries.dirs
            path = []
            current = entry
            cid = current.id
            path.append(current)

            while current.parent.int != 0:
                parent = None
                for i in range(len(dirs)):
                    entry = entries.get_entry(dirs[i])
                    if entry.id.int == current.parent.int:
                        parent = entry
                        break

                if not parent:
                    raise RuntimeError(
                        'Directory doesn\'t reach root!', current)

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
        def write_entry(self, entry, index):
            if not isinstance(entry, Entry): raise TypeError()  # noqa E701
            if not isinstance(index, int): raise TypeError()  # noqa E701

            offset = index * 256 + 1024
            fileobj = self.ioc.fileobj
            if offset != fileobj.seek(offset):
                raise OSError()
            fileobj.write(entry.serialize())

        def load_data(self, entry):
            if entry.type is not Entry.TYPE_FILE:
                raise OSError('Can\'t read non-file.')
            fileobj = self.ioc.fileobj
            if fileobj.seek(entry.offset) != entry.offset:
                raise OSError('Could not seek to new offset')
            return fileobj.read(entry.size)

        def write_data(self, offset, data):
            fileobj = self.ioc.fileobj
            if fileobj.seek(offset) != offset:
                raise OSError('Could not seek to new offset')
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
                raise OSError()

            last = entries.get_entry(entries.get_thithermost())
            data = self.load_data(entry)
            noffset = entries._sector(last.offset+last.size)
            self.write_data(noffset, data)
            empty = Entry.empty(entry.offset, entry.size)

            entry = entry._asdict()
            entry['offset'] = noffset
            entry = Entry(**entry)
            entries.update(entry, idx)

            return empty

    class Query:
        def __init__(self, name='*', follow=False):
            self.__type = (Entry.TYPE_FILE, Entry.TYPE_DIR, Entry.TYPE_LINK)
            self.__follow = follow
            if name == '*':
                self.__name = None
            else:
                self.__name = name
                self.__regex = re.compile(bytes(name, 'utf-8'))
            self.__id = None
            self.__parent = None
            self.__owner = None
            self.__created = None
            self.__modified = None
            self.__deleted = None

        @property
        def follow(self):
            return self.__follow

        @property
        def types(self):
            return self.__type

        def type(self, _type, operand='='):
            if isinstance(_type, tuple):
                self.__type = _type
            elif isinstance(_type, bytes):
                self.__type = (_type)
            else:
                raise TypeError()
            return self

        def id(self, id=None):
            if not isinstance(id, uuid.UUID): raise TypeError()  # noqa E701
            self.__id = id
            return self

        def parent(self, parent, operand='='):
            if not isinstance(parent, uuid.UUID): raise TypeError()  # noqa E701
            if not operand in ['=', '≠']: raise ValueError()  # noqa E701
            self.__parent = (parent, operand)
            return self

        def owner(self, owner, operand='='):
            if not isinstance(owner, uuid.UUID): raise TypeError()  # noqa E701
            if not operand in ['=', '≠']: raise ValueError()  # noqa E701
            self.__owner = (owner, operand)
            return self

        def created(self, created, operand='>'):
            if not isinstance(created, (
                int, str, datetime.datetime)): raise TypeError()  # noqa E701
            if not operand in ['=', '>', '<']: raise ValueError()  # noqa E701
            if isinstance(created, int):
                created = datetime.datetime.fromtimestamp(created)
            elif isinstance(created, str):
                created = datetime.datetime.fromisoformat(created)
            self.__created = (created, operand)
            return self

        def modified(self, modified, operand='>'):
            if not isinstance(modified, (
                int, str, datetime.datetime)): raise TypeError()  # noqa E701
            if not operand in ['=', '>', '<']: raise ValueError()  # noqa E701
            if isinstance(modified, int):
                modified = datetime.datetime.fromtimestamp(modified)
            elif isinstance(modified, str):
                modified = datetime.datetime.fromisoformat(modified)
            self.__modified = (modified, operand)
            return self

        def deleted(self, deleted):
            if not isinstance(deleted, bool): raise TypeError()  # noqa E701
            self.__deleted = deleted
            return self

        def build(self):
            def _type_in(x):
                return x.type in self.__type

            def _name_match(x):
                return bool(self.__regex.match(x.name))

            def _id_is(x):
                return self.__id.int == x.id.int

            def _parent_is(x):
                return x.parent.int == self.__parent[0].int

            def _parent_not(x):
                return x.parent.int != self.__parent[0].int

            def _owner_is(x):
                return x.owner.int == self.__owner[0].int

            def _owner_not(x):
                return x.owner.int != self.__owner[0].int

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

            if self.__name:
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


LOREM = """Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla mollis tincidunt arcu, vitae pulvinar lorem aliquet porta. Nam sit amet diam in sem laoreet dignissim. Nulla eu sapien semper orci porta consequat id vel purus. Vivamus diam lectus, sodales id condimentum eu, cursus sed ipsum. Nam a sapien laoreet, lobortis diam sit amet, pulvinar nisi. In venenatis elementum dolor, non sodales est suscipit ac. Curabitur vitae ligula semper, luctus ante id, tincidunt ante. Suspendisse aliquam nullam."""  # noqa E501

IPSUM = """Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam ut ipsum semper, semper est nec, varius lorem. Donec mollis libero at turpis semper molestie. Aliquam tristique rhoncus lacus at ullamcorper. Curabitur pretium sapien vitae eleifend cursus. Aliquam blandit neque sit amet quam suscipit blandit. Curabitur id lectus velit. Integer vehicula eget nulla vitae ultrices. Pellentesque condimentum lacus sed odio posuere, ac luctus mi dignissim. Morbi hendrerit neque pellentesque varius condimentum. Nullam arcu quam, mattis id ultrices ac, molestie non arcu. Nulla tristique in lacus quis consequat. Phasellus luctus faucibus gravida. Aenean lacinia tempus mi, porta pellentesque sapien scelerisque quis. Cras nec libero vel velit dictum pharetra non sollicitudin arcu.

Integer eu sagittis risus. Praesent tempor semper sapien in ultrices. Aenean purus ipsum, ornare in libero vel, porta porta leo. Maecenas pretium sollicitudin tortor, sit amet porttitor ligula mollis at. Class aptent metus."""  # noqa E501

DOLOR = """Lorem ipsum dolor sit amet, consectetur adipiscing elit. Etiam vel nisl et felis porta malesuada. Maecenas finibus faucibus sem commodo ultrices. Pellentesque sed erat eu dui consectetur tincidunt vel ac leo. Fusce sodales rutrum nisi, luctus vulputate magna ullamcorper ut. Nulla facilisi. Aenean molestie orci leo, nec ultrices leo laoreet eget. Aliquam dui purus, vehicula eu molestie ac, aliquam et neque.

Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia Curae; Vivamus efficitur eros at sodales venenatis. Suspendisse nec nisi vel tellus suscipit porttitor. Fusce at venenatis orci. Ut hendrerit sodales pulvinar. Nulla vitae hendrerit nisl. Suspendisse nec est hendrerit, consectetur dolor ac, luctus massa. Donec dictum, ipsum ac pulvinar ultricies, orci odio iaculis libero, vel ullamcorper sem nibh sit amet mi. Sed molestie lacinia dui sed efficitur. Fusce sed felis ex. Vivamus mauris massa, sodales id egestas et, accumsan nec leo. Nulla nec libero diam. Vivamus euismod sollicitudin magna vitae laoreet. Nulla ac purus feugiat metus mollis condimentum at non erat. Sed et aliquam diam.

Vestibulum suscipit id massa eu condimentum. Quisque euismod, tellus eget convallis vulputate, magna velit posuere urna, non volutpat augue odio eu eros. Etiam malesuada sapien magna, at porta mi aliquam in. Nullam vehicula dui a tellus sollicitudin ultricies eget et risus. Suspendisse eget pulvinar arcu, eu cursus turpis. Nunc non velit porta, egestas ipsum vitae, efficitur elit. Curabitur non tempor eros. Aliquam vehicula sodales erat vel consectetur. Suspendisse consectetur, mi in maximus efficitur, mauris neque pulvinar diam, quis scelerisque enim magna vitae sapien. Proin at euismod neque. Maecenas blandit tortor ex, in accumsan diam volutpat sed. Duis eget leo ac tortor ultrices faucibus sed in diam.

Ut vitae neque mi. Nulla pellentesque turpis sed nisl congue semper. In tincidunt, ipsum nec blandit hendrerit, ex erat dictum libero, eu cursus justo amet."""  # noqa E501

LOREM_DIGEST = hashlib.sha1(bytes(LOREM, 'utf-8')).digest()
IPSUM_DIGEST = hashlib.sha1(bytes(IPSUM, 'utf-8')).digest()
DOLOR_DIGEST = hashlib.sha1(bytes(DOLOR, 'utf-8')).digest()

alphabet = 'abcdefghijklmnopqrstuvwxyz'

archive = Archive.create(path='./test.ar7', owner=uuid.UUID(
    bytes=b'\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x00'))

hierarchy = (
    '/',
    '/cache',
    '/cache/junk',
    '/facade',
    '/facade/churches',
    '/facade/identity',
    '/facade/ministries',
    '/facade/keys',
    '/facade/persons',
    '/facade/profiles',
    '/facade/settings',
)

animals = (
    '/animal',
    '/animal/elephant',
    '/animal/kangaroo',
    '/animal/girafe',
    '/animal/hippo',
    '/animal/horse',
    '/pet',
    '/pet/hamster',
    '/pet/cat',
    '/pet/dog',
    '/pet/parrott',
)

for i in hierarchy:
    archive.mkdir(i)
for i in animals:
    archive.mkdir(i)
archive.remove('/cache/junk')

for i in range(random.randrange(100, 200)):
    archive.mkfile(
        random.choices(animals, k=1)[0] + '/' +
        ''.join(random.choices(
            string.ascii_lowercase + string.digits,
            k=random.randrange(5, 10))) + '.txt',
        bytes(random.choices([LOREM, IPSUM, DOLOR], k=1)[0], 'utf-8')
    )

archive.mkfile('/facade/lorem.txt', bytes(LOREM, 'utf-8'))
archive.mkfile('/facade/churches/ipsum.txt', bytes(IPSUM, 'utf-8'))
archive.mkfile('/facade/persons/dolor.txt', bytes(DOLOR, 'utf-8'))

print(len(archive.load('/facade/lorem.txt')))
print(len(archive.load('/facade/churches/ipsum.txt')))
print(len(archive.load('/facade/persons/dolor.txt')))

archive.save('/facade/lorem.txt', bytes(DOLOR, 'utf-8'))
archive.save('/facade/churches/ipsum.txt', bytes(LOREM, 'utf-8'))
archive.save('/facade/persons/dolor.txt', bytes(IPSUM, 'utf-8'))

print(len(archive.load('/facade/lorem.txt')))
print(len(archive.load('/facade/churches/ipsum.txt')))
print(len(archive.load('/facade/persons/dolor.txt')))

archive.move('/facade/lorem.txt', '/cache')
archive.move('/facade/churches/ipsum.txt', '/cache')
archive.move('/facade/persons/dolor.txt', '/cache')

archive.rename('/cache/lorem.txt', 'foo.txt')
archive.rename('/cache/ipsum.txt', 'bar.txt')
archive.rename('/cache/dolor.txt', 'baz.txt')

archive.chmod('/cache/foo.txt')
archive.chmod('/cache/bar.txt')
archive.chmod('/cache/baz.txt')

archive.move('/cache', '/facade')

archive.remove('/facade/cache/foo.txt')
archive.remove('/facade/cache/bar.txt')
archive.remove('/facade/cache/baz.txt')

for i in range(random.randrange(100, 200)):
    archive.mkfile(
        random.choices(animals, k=1)[0] + '/' +
        ''.join(random.choices(
            string.ascii_lowercase + string.digits,
            k=random.randrange(5, 10))) + '.txt',
        bytes(random.choices([LOREM, IPSUM, DOLOR], k=1)[0], 'utf-8')
    )

entries = archive.glob()
for i in entries:
    try:
        print('Load:', i)
        archive.load(i)
    except OSError as e:
        print(e, i)
