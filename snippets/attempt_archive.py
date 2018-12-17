import os
import struct
import collections
import uuid
import time
import datetime


class Header(collections.namedtuple('Header', field_names=[
    'type',         # 1
    'major',        # 2
    'minor',        # 2
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


class EntryPoint(collections.namedtuple('EntryPoint', field_names=[
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
        return EntryPoint(
            type=EntryPoint.TYPE_BLANK,
            id=uuid.uuid4(),
            parent=None,
            owner=None,
            created=datetime.datetime.fromtimestamp(0),
            modified=datetime.datetime.fromtimestamp(0),
            offset=None,
            size=None,
            length=None,
            compression=EntryPoint.COMP_NONE,
            deleted=None,
            digest=None,
            name=None
        )

    @staticmethod
    def empty(offset, size):
        if not isinstance(offset, int): raise TypeError()  # noqa E701
        if not isinstance(size, int): raise TypeError()  # noqa E701

        return EntryPoint(
            type=EntryPoint.TYPE_EMPTY,
            id=uuid.uuid4(),
            parent=None,
            owner=None,
            created=datetime.datetime.fromtimestamp(0),
            modified=datetime.datetime.fromtimestamp(0),
            offset=offset,
            size=size,
            length=None,
            compression=EntryPoint.COMP_NONE,
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

        return EntryPoint(
            type=EntryPoint.TYPE_DIR,
            id=uuid.uuid4(),
            parent=parent,
            owner=owner,
            created=created,
            modified=modified,
            offset=None,
            size=None,
            length=None,
            compression=EntryPoint.COMP_NONE,
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
            compression = EntryPoint.COMP_NONE
        elif 1 <= compression <= 3 and not isinstance(length, int):
            raise ValueError()

        return EntryPoint(
            type=EntryPoint.TYPE_FILE,
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
            EntryPoint.FORMAT,
            self.type if not isinstance(
                self.type, type(None)) else EntryPoint.TYPE_BLANK,
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
                self.compression, int) else EntryPoint.COMP_NONE,
            self.deleted if isinstance(self.deleted, bool) else False,
            # b'\x00'*17,
            self.digest if isinstance(
                self.digest, (bytes, bytearray)) else b'\x00'*20,
            self.name[:128] if isinstance(
                self.name, (bytes, bytearray)) else b'\x00'*128
        )

    @staticmethod
    def deserialize(data):
        t = struct.unpack(EntryPoint.FORMAT, data)
        return EntryPoint(
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


class Archive:
    def __init__(self, fileobj):
        self.__file = fileobj
        size = os.path.getsize(self.__file.name)
        self.__index = 0

    def create(self, name):
        pass

    def _header():
        return Header()

    def _entry_offset(self, index):
        return 1024 + index * 256


ep = EntryPoint.file(
    'Just_a_stupid_file_name.txt', 0, 1024, b'63870259301694503019')
s = ep.serialize()
ep2 = EntryPoint.deserialize(s)
s2 = ep2.serialize()
print(s == s2)

hp = Header(title='Database_file.cnl')
s3 = hp.serialize()
hp2 = Header.deserialize(s3)
s4 = hp2.serialize()
print(s3 == s4)
