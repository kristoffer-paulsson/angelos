# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Archive implementation."""
import datetime
import os
import struct
import time
import uuid
from pathlib import PurePath
from typing import Union

from archive7.streams import StreamManager, Registry, DataStream, VirtualFileObject
from archive7.fs import FilesystemMixin


class ArchiveHeader:
    """Header for the Archive 7 format."""

    __slots__ = ["major", "minor", "type", "role", "use", "id", "owner", "domain", "node", "created", "title"]
    FORMAT = "!8sHHbbb16s16s16s16sQ256s"

    def __init__(self, owner: uuid.UUID, identity: uuid.UUID = None, node: uuid.UUID = None, domain: uuid.UUID = None,
                 title: Union[bytes, bytearray] = None, type: int = None, role: int = None, use: int = None,
                 major: int = 2, minor: int = 0):
        self.major = major,
        self.minor = minor,
        self.type = type,
        self.role = role,
        self.use = use,
        self.id = identity,
        self.owner = owner,
        self.domain = domain,
        self.node = node,
        self.created = datetime.datetime.now(),
        self.title = title,

    def __bytes__(self):
        return struct.pack(
            ArchiveHeader.FORMAT,
            b"archive7",
            2,
            0,
            self.type if not isinstance(self.type, type(None)) else 0,
            self.role if not isinstance(self.role, type(None)) else 0,
            self.use if not isinstance(self.use, type(None)) else 0,
            self.id.bytes if isinstance(self.id, uuid.UUID) else uuid.uuid4().bytes,
            self.owner.bytes if isinstance(self.owner, uuid.UUID) else b"\x00" * 16,
            self.domain.bytes if isinstance(self.domain, uuid.UUID) else b"\x00" * 16,
            self.node.bytes if isinstance(self.node, uuid.UUID) else b"\x00" * 16,
            int(
                time.mktime(self.created.timetuple())
                if isinstance(self.created, datetime.datetime)
                else time.mktime(datetime.datetime.now().timetuple())
            ),
            self.title[:256] if isinstance(self.title, (bytes, bytearray)) else b"\x00" * 256,
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        metadata = struct.unpack(ArchiveHeader.FORMAT, data)

        if metadata[0] != b"archive7":
            raise RuntimeError("Invalid format")

        return ArchiveHeader(
            type=metadata[3],
            role=metadata[4],
            use=metadata[5],
            identity=uuid.UUID(bytes=metadata[6]),
            owner=uuid.UUID(bytes=metadata[7]),
            domain=uuid.UUID(bytes=metadata[8]),
            node=uuid.UUID(bytes=metadata[9]),
            created=datetime.datetime.fromtimestamp(metadata[10]),
            title=metadata[11].strip(b"\x00"),
            major=metadata[1],
            minor=metadata[2],
        )


class ArchiveEntry:
    """Header for the Archive 7 format."""

    __slots__ = ["type", "id", "parent", "owner", "stream", "created", "modified", "size", "length", "compression",
                 "deleted", "name", "user", "group", "perms"]
    FORMAT = "!c16s16s16s16qqQQQ?256s32s16sH"

    TYPE_FILE = b"f"  # Represents a file
    TYPE_LINK = b"l"  # Represents a link
    TYPE_DIR = b"d"  # Represents a directory

    COMP_NONE = 0
    COMP_ZIP = 1
    COMP_GZIP = 2
    COMP_BZIP2 = 3

    def __init__(self, type: bytes = b"f", identity: uuid.UUID = uuid.uuid4(), parent: uuid.UUID = uuid.UUID(int=0),
                 owner: uuid.UUID = uuid.UUID(int=0), stream: uuid.UUID = uuid.UUID(int=0),
                 created: datetime.datetime = datetime.datetime.fromtimestamp(0),
                 modified: datetime.datetime = datetime.datetime.fromtimestamp(0), size: int = None, length: int = None,
                 compression: int = 0, deleted: bool = False, name: Union[bytes, bytearray] = None,
                 user: Union[bytes, bytearray] = None, group: Union[bytes, bytearray] = None, perms: int = 0o755):
        self.type = type  # Entry type
        self.id = identity  # File id
        self.parent = parent  # File id of parent directory or link to target
        self.owner = owner  # UUID of owner
        self.stream = stream  # UUID of underlying stream
        self.created = created  # Created date/time timestamp
        self.modified = modified  # Modified date/time timestamp
        self.size = size  # File size (compressed)
        self.length = length  # Data length (uncompressed)
        self.compression = compression  # Applied compression
        self.deleted = deleted  # Deleted marker
        self.name = name  # File name
        self.user = user  # Unix user
        self.group = group  # Unix group
        self.perms = perms  # Unix permissions

    def __bytes__(self):
        return struct.pack(
            ArchiveEntry.FORMAT,
            self.type,
            self.id.bytes if isinstance(self.id, uuid.UUID) else uuid.uuid4().bytes,
            self.parent.bytes if isinstance(self.parent, uuid.UUID) else b"\x00" * 16,
            self.owner.bytes if isinstance(self.owner, uuid.UUID) else b"\x00" * 16,
            self.stream.bytes if isinstance(self.owner, uuid.UUID) else b"\x00" * 16,
            int(
                time.mktime(self.created.timetuple())
                if isinstance(self.created, datetime.datetime)
                else time.mktime(datetime.datetime.now().timetuple())
            ),
            int(
                time.mktime(self.modified.timetuple())
                if isinstance(self.modified, datetime.datetime)
                else time.mktime(datetime.datetime.now().timetuple())
            ),
            self.size if isinstance(self.size, int) else 0,
            self.length if isinstance(self.length, int) else 0,
            self.compression if isinstance(self.compression, int) else ArchiveEntry.COMP_NONE,
            self.deleted if isinstance(self.deleted, bool) else False,
            self.name[:256] if isinstance(self.name, (bytes, bytearray)) else b"\x00" * 256,
            self.user[:32] if isinstance(self.user, (bytes, bytearray)) else b"\x00" * 32,
            self.group[:16] if isinstance(self.group, (bytes, bytearray)) else b"\x00" * 16,
            self.perms if isinstance(self.perms, int) else 0o755,
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        metadata = struct.unpack(ArchiveEntry.FORMAT, data)
        return ArchiveEntry(
            type=metadata[0],
            id=uuid.UUID(bytes=metadata[1]),
            parent=uuid.UUID(bytes=metadata[2]),
            owner=uuid.UUID(bytes=metadata[3]),
            stream=uuid.UUID(bytes=metadata[4]),
            created=datetime.datetime.fromtimestamp(metadata[5]),
            modified=datetime.datetime.fromtimestamp(metadata[6]),
            size=metadata[7],
            length=metadata[8],
            compression=metadata[9],
            deleted=metadata[10],
            name=metadata[11].strip(b"\x00"),
            user=metadata[12].strip(b"\x00"),
            group=metadata[13].strip(b"\x00"),
            perms=int(metadata[14]),
        )

    @staticmethod
    def dir(name: str, parent: uuid.UUID = None, owner: uuid.UUID = None, created: datetime.datetime = None,
            modified: datetime.datetime = None, user: str = None, group: str = None, perms: int = None):
        kwargs = {
            "type": ArchiveEntry.TYPE_DIR,
            "id": uuid.uuid4(),
            "created": datetime.datetime.now(),
            "modified": datetime.datetime.now(),
            "name": name.encode("utf-8")[:256],
        }

        if parent:
            kwargs.setdefault("parent", parent)
        if owner:
            kwargs.setdefault("owner", owner)
        if created:
            kwargs.setdefault("created", created)
        if modified:
            kwargs.setdefault("modified", modified)
        if user:
            kwargs.setdefault("user", user.encode("utf-8")[:32])
        if group:
            kwargs.setdefault("group", group.encode("utf-8")[:16])
        if perms:
            kwargs.setdefault("perms", perms)

        return ArchiveEntry(**kwargs)

    @staticmethod
    def link(name: str, link: uuid.UUID, parent: uuid.UUID = None, created: datetime.datetime = None,
             modified: datetime.datetime = None, user: str = None, group: str = None, perms: str = None):
        """Generate entry for file link."""

        kwargs = {
            "type": ArchiveEntry.TYPE_LINK,
            "id": uuid.uuid4(),
            "owner": link,
            "created": datetime.datetime.now(),
            "modified": datetime.datetime.now(),
            "name": name.encode("utf-8")[:256],
        }

        if parent:
            kwargs.setdefault("parent", parent)
        if created:
            kwargs.setdefault("created", created)
        if modified:
            kwargs.setdefault("modified", modified)
        if user:
            kwargs.setdefault("user", user.encode("utf-8")[:32])
        if group:
            kwargs.setdefault("group", group.encode("utf-8")[:16])
        if perms:
            kwargs.setdefault("perms", perms)

        return ArchiveEntry(**kwargs)

    @staticmethod
    def file(name: str, size: int, stream: uuid.UUID, identity: uuid.UUID = None, parent: uuid.UUID = None,
             owner: uuid.UUID = None, created: datetime.datetime = None, modified: datetime.datetime = None,
             compression: int = None, length: int = None, user: str = None, group: str = None, perms: int = None):
        """Entry header for file."""

        kwargs = {
            "type": ArchiveEntry.TYPE_FILE,
            "id": uuid.uuid4(),
            "stream": stream,
            "created": datetime.datetime.now(),
            "modified": datetime.datetime.now(),
            "size": size,
            "name": name.encode("utf-8")[:256],
        }

        if identity:
            kwargs.setdefault("id", identity)
        if parent:
            kwargs.setdefault("parent", parent)
        if owner:
            kwargs.setdefault("owner", owner)
        if created:
            kwargs.setdefault("created", created)
        if modified:
            kwargs.setdefault("modified", modified)
        if user:
            kwargs.setdefault("user", user.encode("utf-8")[:32])
        if group:
            kwargs.setdefault("group", group.encode("utf-8")[:16])
        if perms:
            kwargs.setdefault("perms", perms)
        if compression and length:
            if 1 <= compression <= 3 and not isinstance(length, int):
                raise RuntimeError("Invalid compression type")
            kwargs.setdefault("compression", compression)
            kwargs.setdefault("length", length)
        else:
            kwargs.setdefault("length", size)

        return ArchiveEntry(**kwargs)


class ArchivePath:
    """Record for parent id and entry name."""

    __slots__ = ["id", "key"]

    FORMAT = "!16s16s"

    def __init__(self, identity: uuid.UUID, key: uuid.UUID):
        self.id = identity
        self.key = key

    def __bytes__(self):
        return struct.pack(
            ArchiveEntry.FORMAT,
            self.id.bytes,
            self.key.bytes
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        metadata = struct.unpack(ArchivePath.FORMAT, data)
        return ArchivePath(
            identity=uuid.UUID(bytes=metadata[0]),
            key=uuid.UUID(bytes=metadata[1])
        )

    @staticmethod
    def path(identity: uuid.UUID, parent: uuid.UUID, name: str):
        """Entry header for file."""
        return ArchivePath(
            identity=identity,
            key=uuid.uuid5(parent, name)
        )


class Archive7(FilesystemMixin):
    """

    """

    STREAM_ENTRIES = 4
    STREAM_ENTRIES_JOURNAL = 5

    STREAM_PATHS = 6
    STREAM_PATHS_JOURNAL = 7

    STREAM_HIERARCHY = 8
    STREAM_HIERARCHY_JOURNAL = 9

    def __init__(self, filename: str, secret: bytes):
        self.__entries = None
        self.__paths = None
        self.__hierarchy = None
        self.__descriptors = dict()
        self.__closed = False

        self.__manager = StreamManager(filename, secret)

        if self.__manager.created:
            self.__entries = Registry(
                self.__manager.new_stream(uuid.UUID(int=Archive7.STREAM_ENTRIES)),
                self.__manager.new_stream(uuid.UUID(int=Archive7.STREAM_ENTRIES_JOURNAL)),
                key_size=16,
                value_size=struct.calcsize(DataStream.FORMAT)
            )
            self.__paths = Registry(
                self.__manager.new_stream(uuid.UUID(int=Archive7.STREAM_PATHS)),
                self.__manager.new_stream(uuid.UUID(int=Archive7.STREAM_PATHS_JOURNAL)),
                key_size=16,
                value_size=struct.calcsize(DataStream.FORMAT)
            )
            self.__hierarchy = Registry(
                self.__manager.new_stream(uuid.UUID(int=Archive7.STREAM_HIERARCHY)),
                self.__manager.new_stream(uuid.UUID(int=Archive7.STREAM_HIERARCHY_JOURNAL)),
                key_size=16,
                value_size=struct.calcsize(DataStream.FORMAT)
            )
            root = ArchiveEntry.dir("root")
            root.id = uuid.UUID(int=0)
            root.parent = root.id
            self.__entries.tree.insert(root.id, bytes(root))
        else:
            self.__entries = Registry(
                self.__manager.open_stream(uuid.UUID(int=Archive7.STREAM_ENTRIES)),
                self.__manager.open_stream(uuid.UUID(int=Archive7.STREAM_ENTRIES_JOURNAL)),
                key_size=16,
                value_size=struct.calcsize(ArchiveEntry.FORMAT)
            )
            self.__paths = Registry(
                self.__manager.open_stream(uuid.UUID(int=Archive7.STREAM_PATHS)),
                self.__manager.open_stream(uuid.UUID(int=Archive7.STREAM_PATHS_JOURNAL)),
                key_size=16,
                value_size=struct.calcsize(ArchiveEntry.FORMAT)
            )
            self.__hierarchy = Registry(
                self.__manager.open_stream(uuid.UUID(int=Archive7.STREAM_HIERARCHY)),
                self.__manager.open_stream(uuid.UUID(int=Archive7.STREAM_HIERARCHY_JOURNAL)),
                key_size=16,
                value_size=struct.calcsize(ArchiveEntry.FORMAT)
            )

    @property
    def closed(self):
        return self.__closed

    def close(self):
        if not self.__closed:
            for fd in self.__descriptors:
                fd.close()
            self.__hierarchy.close()
            self.__paths.close()
            self.__entries.close()
            self.__manager.close()

    def __del__(self):
        self.close()

    def __find_parent(self, name: str, parent: uuid.UUID = uuid.UUID(int=0)) -> uuid.UUID:
        return uuid.uuid5(parent, name)

    def __find_directory(self, dirname: PurePath) -> ArchiveEntry:
        """Find directory for current path.

        Args:
            dirname (pathlib.PurePath):
                The path to follow.

        Returns (ArchiveEntry):
            The entry of the path or None.

        """
        entry = None
        for name in dirname.parts:
            key = uuid.uuid5(uuid.UUID(int=0), "root") if name == "/" else uuid.uuid5(entry.parent, name)
            record = self.__paths.tree.get(key)
            entry = self.__entries.tree.get(record.id)

        if entry.type != ArchiveEntry.TYPE_DIR:
            raise OSError("Entry not a directory")
        return entry

    def __find_file(self, directory: ArchiveEntry, name: str) -> ArchiveEntry:
        """Find file in directory

        Args:
            name:

        Returns:

        """
        key = uuid.uuid5(directory.id, name)
        record = self.__paths.tree.get(key)
        entry = self.__entries.tree.get(record.identity)
        if entry.type not in (ArchiveEntry.TYPE_FILE, ArchiveEntry.TYPE_LINK):
            raise OSError("File not found")
        return entry

    def __add_entry(self, entry: ArchiveEntry):
        self.__entries.tree.insert(entry.id, bytes(entry))
        record = ArchivePath.path(entry.id, entry.parent, entry.name)
        self.__paths.tree.insert(record.key, bytes(record))

    def open(self, path: str, mode: str = "r") -> VirtualFileObject:
        """Open file of path.

        Args:
            path (str):
                Path to file.
            mode (str):
                Mode to open file in.

        Returns (VirtualFileObject):
            File descriptor of open file or None.

        """
        dirname, name = os.path.split(path)
        directory = self.__find_directory(PurePath(dirname))
        entry = self.__find_file(directory, name)
        if entry is None:
            stream = self.__manager.new_stream()
            entry = ArchiveEntry.file(name=name, parent=directory.id, stream=stream.identity)
            self.__add_entry(entry)
            # Create a new entry and stream
        else:
            if not entry.type == ArchiveEntry.TYPE_FILE:
                raise OSError("Path not a file")
            stream = self.__manager.open_stream(entry.stream)

        fd = VirtualFileObject(name=entry.name, stream=stream, mode=mode)
        self.__descriptors[entry.id] = fd
        return fd

    def access(self, path, mode, dir_fd=None, effective_ids=False, follow_symlinks=True):
        pass

    def chflags(self, path, flags, follow_symlinks=True):
        pass

    def chmod(self, path, mode, dir_fd=None, follow_symlinks=True):
        pass

    def chown(self, path, uid, gid, dir_fd=None, follow_symlinks=True):
        pass

    def lchflags(self, path, flags):
        pass

    def lchmod(self, path, mode):
        pass

    def lchown(self, path, uid, gid):
        pass

    def link(self, src, dst, src_dir_fd=None, dst_dir_fd=None, follow_symlinks=True):
        pass

    def listdir(self, path="."):
        pass

    def lstat(self, path, dir_fd=None):
        pass

    def mkdir(self, path, mode=0o777, dir_fd=None):
        pass

    def makedirs(self, name, mode=0o777, exist_ok=False):
        pass

    def mkfifo(self, path, mode=0o666, dir_fd=None):
        pass

    def readlink(self, path, dir_fd=None):
        pass

    def remove(self, path, dir_fd=None):
        pass

    def removedirs(self, name):
        pass

    def rename(self, src, dst, src_dir_fd=None, dst_dir_fd=None):
        pass

    def renames(self, old, new):
        pass

    def replace(self, src, dst, src_dir_fd=None, dst_dir_fd=None):
        pass

    def rmdir(self, path, dir_fd=None):
        pass

    def scandir(self, path="."):
        pass

    def stat(self, path, dir_fd=None, follow_symlinks=True):
        pass

    def symlink(self, src, dst, target_is_directory=False, dir_fd=None):
        pass

    def sync(self):
        pass

    def truncate(self, path, length):
        pass

    def unlink(self, path, dir_fd=None):
        pass

    # def time(self, path, times=None, ns, dir_fd=None, follow_symlinks=True):
    #    pass

    def walk(self, top, topdown=True, onerror=None, followlinks=False):
        pass

    def fwalk(self, top=".", topdown=True, onerror=None, follow_symlinks=False, dir_fd=None):
        pass
