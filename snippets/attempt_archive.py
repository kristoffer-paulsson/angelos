import os
import struct
import collections
import uuid
import time
import datetime
import enum


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


class Archive:
    def __init__(self, fileobj):
        self.__file = fileobj
        self.__header = None
        self.__entries = None
        self.__size = os.path.getsize(self.__file.name)
        self.__index = 0
        self.__hierarchy = None

        self.__load()

    def __load(self):
        self.__file.seek(0)
        self.__header = Header.unserialize(
            struct.unpack(Header.FORMAT, self.__file.read(
                struct.calcsize(Header.FORMAT))))

        self.__file.seek(self._entry_offset(self.__index))
        entries = []
        for i in range(self.__header.entries):
            entries.append(Entry.unserialize(
                struct.unpack(Entry.FORMAT, self.__file.read(
                    struct.calcsize(Entry.FORMAT)))))

        self.__entries = Archive.Entries(entries)
        self.__hierarchy = Archive.Hierarchy(self._entreiss.__dirs)

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

    class Entries:
        def __init__(self, entries):
            self.__all = entries
            self.__files = []
            self.__dirs = []
            self.__empties = []
            self.__blanks = []

            for i in range(self.__all):
                if self.__entries[i].type == Entry.TYPE_FILE:
                    self.__files.append(i)
                elif self.__entries[i].type == Entry.TYPE_DIR:
                    self.__dirs.append(i)
                elif self.__entries[i].type == Entry.TYPE_EMPTY:
                    self.__empties.append(i)
                elif self.__entries[i].type == Entry.TYPE_BLANK:
                    self.__blanks.append(i)
                else:
                    raise OSError('Unknown entry type: {}'.format(
                        self.__entries[i].type))

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

    class Hierarchy:
        def __init__(self, dirs):
            self.__paths = {}
            self.__ids = {}
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

    class Operation:
        pass


archive = Archive.create(path='./test.ar7', owner=uuid.UUID(
    bytes=b'\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x00'))
