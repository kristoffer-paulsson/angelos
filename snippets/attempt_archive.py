import os
import struct
import collections
import uuid
import time
import datetime
import enum
import hashlib
import sys
import math

from ..angelos.ioc import Container, ContainerAware


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
            b'archive\x07',
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
        t = struct.unpack(Header.FORMAT, data)

        if t[0] != b'archive\x07':
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
    uuid.uuid4(),
    uuid.UUID(bytes=b'\x00'*16),
    uuid.UUID(bytes=b'\x00'*16),
    datetime.datetime.now(),
    datetime.datetime.now(),
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
    TYPE_DIR = b'd'     # Represents a directory
    TYPE_EMPTY = b'e'   # Represents an empty block
    TYPE_BLANK = b'b'   # Represents an empty entry
    COMP_NONE = 0
    COMP_ZIP = 1
    COMP_GZIP = 2
    COMP_BZIP2 = 3

    @staticmethod
    def blank():
        return Entry(
            type=Entry.TYPE_BLANK,
            id=uuid.uuid4(),
            parent=None,
            owner=None,
            created=datetime.datetime.fromtimestamp(0),
            modified=datetime.datetime.fromtimestamp(0),
            offset=None,
            size=None,
            length=None,
            compression=Entry.COMP_NONE,
            deleted=None,
            digest=None,
            name=None
        )

    @staticmethod
    def empty(offset, size):
        if not isinstance(offset, int): raise TypeError()  # noqa E701
        if not isinstance(size, int): raise TypeError()  # noqa E701

        return Entry(
            type=Entry.TYPE_EMPTY,
            id=uuid.uuid4(),
            parent=None,
            owner=None,
            created=datetime.datetime.fromtimestamp(0),
            modified=datetime.datetime.fromtimestamp(0),
            offset=offset,
            size=size,
            length=None,
            compression=Entry.COMP_NONE,
            deleted=None,
            digest=None,
            name=None
        )

    @staticmethod
    def dir(name, parent=None, owner=None, created=None, modified=None):
        if not isinstance(name, str): raise TypeError()  # noqa E701
        if not isinstance(parent, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(owner, (type(None), uuid.UUID)): raise TypeError()  # noqa E701
        if not isinstance(created, (type(None), datetime.datetime)): raise TypeError()  # noqa E701
        if not isinstance(modified, (type(None), datetime.datetime)): raise TypeError()  # noqa E701

        if not created:
            created = datetime.datetime.now()
        if not modified:
            modified = datetime.datetime.now()

        return Entry(
            type=Entry.TYPE_DIR,
            id=uuid.uuid4(),
            parent=parent,
            owner=owner,
            created=created,
            modified=modified,
            offset=None,
            size=None,
            length=None,
            compression=Entry.COMP_NONE,
            deleted=None,
            digest=None,
            name=name.encode('utf-8')[:128]
        )

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

        if not id:
            id = uuid.uuid4()

        if not created:
            created = datetime.datetime.now()
        if not modified:
            modified = datetime.datetime.now()

        if not compression:
            length = size
            compression = Entry.COMP_NONE
        elif 1 <= compression <= 3 and not isinstance(length, int):
            raise ValueError()

        return Entry(
            type=Entry.TYPE_FILE,
            id=id,
            parent=parent,
            owner=owner,
            created=created,
            modified=modified,
            offset=offset,
            size=size,
            length=length,
            compression=compression,
            deleted=False,
            digest=digest[:20],
            name=name.encode('utf-8')[:128]
        )

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


class DelMode(enum.IntEnum):
    SOFT = 1  # Raise file delete flag
    HARD = 2  # Raise  file delete flag, set size and offset to zero, add empty block.  # noqa #E501
    ERASE = 3  # Replace file with empty block


class Archive(ContainerAware):
    def __init__(self, fileobj):
        self.__file = fileobj
        self.__header = None
        self.__size = os.path.getsize(self.__file.name)
        self.__index = 0

        self.__file.seek(0)
        self.__header = Header.deserialize(
            struct.unpack(Header.FORMAT, self.__file.read(
                struct.calcsize(Header.FORMAT))))

        self.__file.seek(self._entry_offset(self.__index))
        entries = []
        for i in range(self.__header.entries):
            entries.append(Entry.unserialize(
                struct.unpack(Entry.FORMAT, self.__file.read(
                    struct.calcsize(Entry.FORMAT)))))

        ContainerAware.__init__(self, Container(config={
            'archive': self,
            'entries': lambda s: Archive.Entries(s, entries),
            'hierarchy': lambda s: Archive.Hierarchy(s),
            'operations': lambda s: Archive.Operations(s),
            'fileobj': lambda s: self.__file
        }))

    def _entry_offset(self, index):
        return 1024 + index * 256

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

    def move(self):
        pass

    def chown(self):
        pass

    def remove(self):
        pass

    def rename(self):
        pass

    def replace(self):
        pass

    def mkdir(self, name):
        """
        Make a new directory in the archive hierarchy.
            name        The full path and name of new directory
            returns     the entry ID
        """
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
        dirname = os.path.dirname(name)
        name = os.path.basename(name)

        if parent:
            ids = self.ioc.hierarchy.ids
            if parent not in ids.keys():
                raise OSError('Parent folder doesn\'t exist')
        elif dirname:
            paths = self.ioc.hierarchy.paths
            if dirname in paths.keys():
                parent = paths[dirname]

        entry = Entry.file(
            name=name, size=len(data), offset=0,
            digest=hashlib.sha1(data).digest(),
            id=id, parent=parent, owner=owner, created=created,
            modified=modified, length=len(data))

        return self.ioc.entries.add(entry, data)

    def update(self):
        pass

    def load(self):
        pass

    class Entries(ContainerAware):
        def __init__(self, ioc, entries):
            ContainerAware.__init__(self, ioc)
            self.__all = entries
            self.__files = []
            self.__dirs = []
            self.__empties = []
            self.__blanks = []

            for i in range(self.__all):
                if self.__all[i].type == Entry.TYPE_FILE:
                    self.__files.append(i)
                elif self.__all[i].type == Entry.TYPE_DIR:
                    self.__dirs.append(i)
                elif self.__all[i].type == Entry.TYPE_EMPTY:
                    self.__empties.append(i)
                elif self.__all[i].type == Entry.TYPE_BLANK:
                    self.__blanks.append(i)
                else:
                    raise OSError('Unknown entry type: {}'.format(
                        self.__all[i].type))

        def get_empty(self, size):
            """
            Finds the largest empty space block that is large enough.
            Returns entry index or None
            """
            current = None
            current_size = sys.maxint

            for i in self.__empties:
                if current_size >= self.__all[i].size >= size:
                    current = i
                    current_size = self.__all[i].size

            if isinstance(current, int):
                return self.__all[current]
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
                return self.__blanks.popleft()
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

        def make_blanks(self, num=8):
            """
            Create more blank entries by allocating more space in the beginning
            of the file.
            num     Number of new blanks
            """
            if not len(self.__files):
                # If no files just add x number of blanks
                for i in range(num):
                    entry = Entry.blank()
                    self.__all.append(entry)
                    self.__blanks.append(entry)
                    self.ioc.operation.write_entry(entry, len(self.__all))
            else:
                num = int(math.ceil(num / 4) * 4)
                cnt = 0
                while num:
                    idx = self.get_hithermost()
                    hithermost = self.__all[idx]
                    if hithermost.type == Entry.TYPE_EMPTY:
                        if hithermost.size > num * 256:
                            pass  # Shrink size of empty by increasing offset and fill with blanks
                        elif hithermost.size <= num * 256:
                            pass  # Replace the empty block with blanks and entry with blank, iterate
                        # else:
                        #     pass  # Replace the empty block with blanks and entry with blank
                    elif hithermost.type == Entry.TYPE_FILE:
                        # Move file to end and update entry
                        if hithermost.size > num * 256:
                            pass  # Fill space with blanks and add an empty entry for the rest
                        elif hithermost.size <= num * 256:
                            pass  # Fill space with blanks
            return cnt

        def get_hithermost(self):
            idx = None
            offset = sys.maxint

            for i in range(len(self.__all)):
                if offset > self.__all[i].offset > 0 and (
                        self.__all[i].type == Entry.TYPE_FILE or
                        self.__all[i].type == Entry.TYPE_EMPTY):
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def get_thithermost(self):
            idx = None
            offset = sys.minint

            for i in range(len(self.__all)):
                if offset < self.__all[i].offset < sys.maxint and (
                        self.__all[i].type == Entry.TYPE_FILE or
                        self.__all[i].type == Entry.TYPE_EMPTY):
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def update(self, entry, idx):
            """Updates an entry, saves it and keep hierachy clean."""
            pass

        def add(self, entry, data=None):
            if entry.type == Entry.TYPE_DIR:
                # Look for a blank entry
                bidx = self.get_blank()
                if isinstance(bidx, type(None)):
                    self.make_blanks()
                    bidx = self.get_blank()

                # Update entry index
                self.__all[bidx] = entry
                self.__dir.append(entry)
                # Save entry update to file
                self.ioc.operation.write_entry(entry, bidx)

            elif entry.type == Entry.TYPE_FILE:
                pass
            else:
                raise ValueError('Unkown entry type.', entry.type)

        @property
        def files(self):
            return self.__files

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
            self.__paths = {}
            self.__ids = {}
            dirs = self.ioc.entries.dirs
            zero = uuid.UUID(bytes=b'\x00'*16)

            for i in range(len(dirs)):
                path = []
                search_path = ''
                path.append(dirs[i])
                current = dirs[i]

                while current.parent.int is not zero.int:
                    parents = self._parent(dirs, current)

                    if len(parents) == 0:
                        raise RuntimeError(
                            'Directory doesn\'t reach root!', current)
                    elif len(parents) > 1:
                        raise ValueError(
                            'Multiple directories with same ID', current)
                    path.append(parents[0])
                    current = parents[0]

                    cid = current.id
                    for j in range(len(path), 0, -1):
                        search_path += '/'+path[i].name

                    self.__paths[search_path] = cid
                    self.__ids[cid] = search_path

        def _parent(self, lst, current):
            return filter(lambda x: x.id.int == current.parent.int, lst)

        @property
        def paths(self):
            return self.__paths

        @property
        def ids(self):
            return self.__ids

    class Operation(ContainerAware):
        def write_entry(self, entry, index):
            if not isinstance(entry, Entry): raise TypeError()  # noqa E701
            if not isinstance(index, int): raise TypeError()  # noqa E701

            offset = index * 256 + 1024
            fileobj = self.ioc.fileobj
            if offset != fileobj.seek(offset):
                raise OSError()
            fileobj.write(entry.serialize())

        def load_data(self, entry):
            fileobj = self.ioc.fileobj
            fileobj.seek(entry.offset)
            return fileobj.read(entry.size)

        def write_data(self, offset, data):
            fileobj = self.ioc.fileobj
            fileobj.seek(offset)
            fileobj.write(data)

        def move_end(self, idx):
            """
            Move data for a file to the end of the archive
            idx         Index of entry
            returns     Non-registered empty entry
            """
            entries = self.ioc.entries
            entry = entries.all[idx]
            if not entry.type == Entry.TYPE_FILE:
                raise OSError()

            last = entries.all[entries.get_thithermost()]
            data = self.load_data(entry)
            self.write_data(last.offset + last.size, data)
            empty = Entry.empty(entry.offset, entry.size)

            entry = entry.asdict()
            entry.offset = last.offset + last.size
            entry = Entry.file(**entry)
            entries.update(entry, idx)

            return empty

        def allocate(self, space):
            """
            Allocates new space in the file.
            space       bytes to allocate
            Returns     offset
            """
            pass


# archive = Archive.create(path='./test.ar7', owner=uuid.UUID(
#    bytes=b'\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x00'))
