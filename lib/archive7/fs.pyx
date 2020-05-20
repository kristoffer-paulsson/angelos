# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""File system."""
import datetime
import struct
import time
import uuid
from abc import ABC, abstractmethod
from typing import Union

from archive7.streams import DynamicMultiStreamManager, Registry


class EntryRecord:
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
            EntryRecord.FORMAT,
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
            self.compression if isinstance(self.compression, int) else EntryRecord.COMP_NONE,
            self.deleted if isinstance(self.deleted, bool) else False,
            self.name[:256] if isinstance(self.name, (bytes, bytearray)) else b"\x00" * 256,
            self.user[:32] if isinstance(self.user, (bytes, bytearray)) else b"\x00" * 32,
            self.group[:16] if isinstance(self.group, (bytes, bytearray)) else b"\x00" * 16,
            self.perms if isinstance(self.perms, int) else 0o755,
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        metadata = struct.unpack(EntryRecord.FORMAT, data)
        return EntryRecord(
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
            "type": EntryRecord.TYPE_DIR,
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

        return EntryRecord(**kwargs)

    @staticmethod
    def link(name: str, link: uuid.UUID, parent: uuid.UUID = None, created: datetime.datetime = None,
             modified: datetime.datetime = None, user: str = None, group: str = None, perms: str = None):
        """Generate entry for file link."""

        kwargs = {
            "type": EntryRecord.TYPE_LINK,
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

        return EntryRecord(**kwargs)

    @staticmethod
    def file(name: str, size: int, stream: uuid.UUID, identity: uuid.UUID = None, parent: uuid.UUID = None,
             owner: uuid.UUID = None, created: datetime.datetime = None, modified: datetime.datetime = None,
             compression: int = None, length: int = None, user: str = None, group: str = None, perms: int = None):
        """Entry header for file."""

        kwargs = {
            "type": EntryRecord.TYPE_FILE,
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

        return EntryRecord(**kwargs)


class PathRecord:
    """Record for parent id and entry name."""

    __slots__ = ["id", "key"]

    FORMAT = "!16s16s"

    def __init__(self, identity: uuid.UUID, key: uuid.UUID):
        self.id = identity
        self.key = key

    def __bytes__(self):
        return struct.pack(
            PathRecord.FORMAT,
            self.id.bytes,
            self.key.bytes
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        metadata = struct.unpack(PathRecord.FORMAT, data)
        return PathRecord(
            identity=uuid.UUID(bytes=metadata[0]),
            key=uuid.UUID(bytes=metadata[1])
        )

    @staticmethod
    def path(identity: uuid.UUID, parent: uuid.UUID, name: str):
        """Entry header for file."""
        return PathRecord(
            identity=identity,
            key=uuid.uuid5(parent, name)
        )


class ListingRecord:
    """Record of directory listing."""
    __slots__ = []

    FORMAT = "!16s"

    def __init__(self, identity: uuid.UUID):
        self.id = identity

    def __bytes__(self):
        return struct.pack(
            PathRecord.FORMAT,
            self.id.bytes,
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        metadata = struct.unpack(ListingRecord.FORMAT, data)
        return ListingRecord(
            identity=uuid.UUID(bytes=metadata[0])
        )


class FileSystemStreamManager(DynamicMultiStreamManager):
    """Stream management with all necessary registries for a filesystem and entry management."""
    SPECIAL_BLOCK_COUNT = 1
    SPECIAL_STREAM_COUNT = 9

    STREAM_ENTRIES = 3
    STREAM_ENTRIES_WAL = 4

    STREAM_PATHS = 5
    STREAM_PATHS_WAL = 6

    STREAM_LISTINGS = 7
    STREAM_LISTINGS_WAL = 8

    def __init__(self, filename: str, secret: bytes):
        DynamicMultiStreamManager.__init__(self, filename, secret)
        self.__entries = None
        self.__paths = None
        self.__listings = None

    def __start(self):
        self.__entries = Registry(
            main=self.special_stream(self.STREAM_ENTRIES),
            wal=self.special_stream(self.STREAM_ENTRIES_WAL),
            key_size=16,
            value_size=struct.calcsize(EntryRecord.FORMAT),
        )
        self.__paths = Registry(
            main=self.special_stream(self.STREAM_PATHS),
            wal=self.special_stream(self.STREAM_PATHS_WAL),
            key_size=16,
            value_size=struct.calcsize(PathRecord.FORMAT),
        )
        self.__listings = Registry(
            main=self.special_stream(self.STREAM_LISTINGS),
            wal=self.special_stream(self.STREAM_LISTINGS_WAL),
            key_size=16,
            value_size=16,
        )

    def _setup(self):
        self.__start()

    def _open(self):
        self.__start()

    def _close(self):
        self.__entries.close()
        self.__paths.close()
        self.__listings.close()
        DynamicMultiStreamManager._close()


class FilesystemMixin(ABC):
    """Mixin for all essential function calls for a file system."""

    @abstractmethod
    def access(self, path, mode, *, dir_fd=None, effective_ids=False, follow_symlinks=True):
        pass

    @abstractmethod
    def chflags(self, path, flags, *, follow_symlinks=True):
        pass

    @abstractmethod
    def chmod(self, path, mode, *, dir_fd=None, follow_symlinks=True):
        pass

    @abstractmethod
    def chown(self, path, uid, gid, *, dir_fd=None, follow_symlinks=True):
        pass

    @abstractmethod
    def lchflags(self, path, flags):
        pass

    @abstractmethod
    def lchmod(self, path, mode):
        pass

    @abstractmethod
    def lchown(self, path, uid, gid):
        pass

    @abstractmethod
    def link(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None, follow_symlinks=True):
        pass

    @abstractmethod
    def listdir(self, path="."):
        pass

    @abstractmethod
    def lstat(self, path, *, dir_fd=None):
        pass

    @abstractmethod
    def mkdir(self, path, mode=0o777, *, dir_fd=None):
        pass

    @abstractmethod
    def makedirs(self, name, mode=0o777, exist_ok=False):
        pass

    @abstractmethod
    def mkfifo(self, path, mode=0o666, *, dir_fd=None):
        pass

    @abstractmethod
    def readlink(self, path, *, dir_fd=None):
        pass

    @abstractmethod
    def remove(self, path, *, dir_fd=None):
        pass

    @abstractmethod
    def removedirs(self, name):
        pass

    @abstractmethod
    def rename(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None):
        pass

    @abstractmethod
    def renames(self, old, new):
        pass

    @abstractmethod
    def replace(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None):
        pass

    @abstractmethod
    def rmdir(self, path, *, dir_fd=None):
        pass

    @abstractmethod
    def scandir(self, path="."):
        pass

    @abstractmethod
    def stat(self, path, *, dir_fd=None, follow_symlinks=True):
        pass

    @abstractmethod
    def symlink(self, src, dst, target_is_directory=False, *, dir_fd=None):
        pass

    @abstractmethod
    def sync(self):
        pass

    @abstractmethod
    def truncate(self, path, length):
        pass

    @abstractmethod
    def unlink(self, path, *, dir_fd=None):
        pass

    @abstractmethod
    def time(self, path, times=None, *, ns, dir_fd=None, follow_symlinks=True):
        pass

    @abstractmethod
    def walk(self, top, topdown=True, onerror=None, followlinks=False):
        pass

    @abstractmethod
    def fwalk(self, top=".", topdown=True, onerror=None, *, follow_symlinks=False, dir_fd=None):
        pass


class AbstractVirtualFilesystem(ABC):
    """Abstract class for a virtual file system."""

    def __init__(self):
        pass

    @abstractmethod
    def unmount(self):
        pass


class AbstractFilesystemSession(ABC):
    """Abstract class for a file system session. (current directory support)."""
    def __init__(self):
        pass

    @abstractmethod
    def chdir(self, path):
        pass

    @abstractmethod
    def chroot(self, path):
        pass

    @abstractmethod
    def fchdir(self, fd):
        pass

    @abstractmethod
    def getcwd(self):
        pass

    @abstractmethod
    def getcwdb(self):
        pass