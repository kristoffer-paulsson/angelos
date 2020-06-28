# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""File system."""
import datetime
import enum
import os
import struct
import time
import uuid
from abc import ABC, abstractmethod
from collections.abc import Iterable
from pathlib import PurePath
from typing import Union, Iterator

from libangelos.archive7.base import DATA_SIZE
from libangelos.archive7.streams import DynamicMultiStreamManager, Registry, DataStream, VirtualFileObject
from libangelos.archive7.tree import SimpleBTree, MultiBTree

TYPE_FILE = b"f"  # Represents a file
TYPE_LINK = b"l"  # Represents a link
TYPE_DIR = b"d"  # Represents a directory
TYPE_ERR = b"e"  # Represent a missing entry


class EntryRecord:
    """Header for the Archive 7 format."""

    __slots__ = ["type", "id", "parent", "owner", "stream", "created", "modified", "size", "length", "compression",
                 "deleted", "name", "user", "group", "perms"]
    FORMAT = "!c16s16s16s16sqqQQQ?256s32s16sH"

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
            identity=uuid.UUID(bytes=metadata[1]),
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
            "type": TYPE_DIR,
            "identity": uuid.uuid4(),
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
            "type": TYPE_LINK,
            "identity": uuid.uuid4(),
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
            "type": TYPE_FILE,
            "identity": uuid.uuid4(),
            "stream": stream,
            "created": datetime.datetime.now(),
            "modified": datetime.datetime.now(),
            "size": size,
            "name": name.encode("utf-8")[:256],
        }

        if identity:
            kwargs.setdefault("identity", identity)
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

    @staticmethod
    def err(identity: uuid.UUID, parent: uuid.UUID):
        """Generate entry for file link."""

        kwargs = {
            "type": TYPE_ERR,
            "identity": identity,
            "parent": parent
        }

        return EntryRecord(**kwargs)


class EntryRegistry(Registry):
    """Registry for all file, link and directory entries."""

    __slots__ = []

    def _init_tree(self):
        return SimpleBTree.factory(
            VirtualFileObject(
                self._manager.special_stream(FileSystemStreamManager.STREAM_ENTRIES),
                "entries", "wb+"
            ),
            order=9,
            value_size=struct.calcsize(EntryRecord.FORMAT),
            page_size=DATA_SIZE
        )


class PathRecord:
    """Record for parent id and entry name."""

    __slots__ = ["id", "type"]

    FORMAT = "!c16s"

    def __init__(self, type_: bytes, identity: uuid.UUID):
        self.type = type_  # Entry type
        self.id = identity

    def __bytes__(self):
        return struct.pack(
            PathRecord.FORMAT,
            self.type,
            self.id.bytes,
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> tuple():
        metadata = struct.unpack(PathRecord.FORMAT, data)
        return PathRecord(
            type_=metadata[0],
            identity=uuid.UUID(bytes=metadata[1]),
        )

    @staticmethod
    def path(type_: bytes, identity: uuid.UUID):
        """Entry header for file."""
        return PathRecord(
            type_=type_,
            identity=identity
        )


class PathRegistry(Registry):
    """Registry for directory traversal and entry uniqueness."""

    __slots__ = []

    def _init_tree(self):
        return SimpleBTree.factory(
            VirtualFileObject(
                self._manager.special_stream(FileSystemStreamManager.STREAM_PATHS),
                "paths", "wb+"
            ),
            order=104,
            value_size=struct.calcsize(PathRecord.FORMAT),
            page_size=DATA_SIZE
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


class ListingRegistry(Registry):
    """Registry for directory listings."""

    __slots__ = []

    def _init_tree(self):
        return MultiBTree.factory(
            VirtualFileObject(
                self._manager.special_stream(FileSystemStreamManager.STREAM_LISTINGS),
                "listings", "wb+"
            ),
            order=248,
            value_size=struct.calcsize(ListingRecord.FORMAT),
            page_size=DATA_SIZE
        )


class FileObject(VirtualFileObject):
    """File object that is FileIO compliant."""

    __slots__ = ["_identity"]

    def __init__(self, identity: uuid.UUID, stream: DataStream, filename: str, mode: str = "r"):
        self._identity = identity
        VirtualFileObject.__init__(self, stream, filename, mode)

    def _close(self):
        self._stream.close()
        self._stream.manager.release(self)

    def fileno(self) -> uuid.UUID:
        """File object entry UUID.

        Returns (uuid.UUID):
            File UUID number

        """
        return self._identity


class Delete(enum.IntEnum):
    """Delete mode flags."""

    SOFT = 1  # Raise file delete flag
    HARD = 2  # Raise  file delete flag, set size and offset to zero, add empty block.  # noqa #E501
    ERASE = 3  # Replace file with empty block


class HierarchyTraverser(Iterable):
    """Traverse the file system hierarchy at a defined starting point."""

    def __init__(self, identity: uuid.UUID, entries: EntryRegistry, paths: PathRegistry, listings: ListingRegistry):
        self.__identity = identity
        self.__segments = list()

        self.__entries = entries
        self.__paths = paths
        self.__listings = listings

    def _get_entry(self, item: uuid.UUID):
        meta = self.__entries.tree.get(key=item)
        if meta:
            return EntryRecord.meta_unpack(meta)
        else:
            return EntryRecord.err(item, None)

    def _iterate_dir(self, record: EntryRecord):
        self.__segments.append(record.name.decode())
        yield record, "/" + os.path.join(*self.__segments)[5:]
        for item in self.__listings.tree.traverse(record.id):
            entry = self._get_entry(uuid.UUID(bytes=item))
            if entry.type == TYPE_ERR:
                entry.parent = record.id
                yield entry, "/" + os.path.join(*self.__segments, "<error>")[5:]
            elif entry.type != TYPE_DIR:
                yield entry, "/" + os.path.join(*self.__segments, entry.name.decode())[5:]
            else:
                for entry2, path in self._iterate_dir(entry):
                    yield entry2, path
        self.__segments.pop()

    def __iter__(self):
        entry = self._get_entry(self.__identity)
        if entry.type != TYPE_DIR:
            yield entry, "/" + os.path.join(*self.__segments, entry.name.decode())[5:]
        else:
            for entry2, path in self._iterate_dir(entry):
                yield entry2, path

    @property
    def path(self) -> str:
        """Current path."""
        return os.path.join(*self.__segments)


class FileSystemStreamManager(DynamicMultiStreamManager):
    """Stream management with all necessary registries for a filesystem and entry management."""
    SPECIAL_STREAM_COUNT = 5

    STREAM_ENTRIES = 2
    STREAM_PATHS = 3
    STREAM_LISTINGS = 4

    def __init__(self, filename: str, secret: bytes):
        self.__descriptors = dict()
        self.__entries = None
        self.__paths = None
        self.__listings = None
        DynamicMultiStreamManager.__init__(self, filename, secret)

    def __start(self):
        self.__entries = EntryRegistry(self)
        self.__paths = PathRegistry(self)
        self.__listings = ListingRegistry(self)

    def __install(self):
        entry = EntryRecord.dir(name="root", parent=uuid.UUID(int=0))
        entry.id = uuid.UUID(int=0)
        path = PathRecord.path(entry.type, entry.id)

        self.__entries.tree.insert(key=entry.id, value=bytes(entry))
        self.__paths.tree.insert(key=uuid.uuid5(entry.parent, entry.name.decode()), value=bytes(path))
        self.__listings.tree.insert(key=entry.id, value=set())

    def _setup(self):
        self.__start()
        self.__install()

    def _open(self):
        self.__start()

    def _close(self):
        for vfd in self.__descriptors.values():
            vfd.close()

        self.__entries.close()
        self.__paths.close()
        self.__listings.close()

        DynamicMultiStreamManager._close(self)

    def __path_from_entry(self, entry: EntryRecord):
        return uuid.uuid5(entry.parent, entry.name.decode())

    def __follow_link(self, identity: uuid.UUID) -> EntryRecord:
        link = EntryRecord.meta_unpack(self.__entries.tree.get(key=identity))
        return EntryRecord.meta_unpack(self.__entries.tree.get(key=link.owner))

    def resolve_path(self, filename: PurePath, follow_link: bool = False) -> uuid.UUID:
        """Resolve a path by walking it.

        Args:
            filename (PurePath):
                Path to resolve
            follow_link (bool):
                Whether to follow links

        Returns (uuid.UUID):
            UUID of the deepest file or directory

        """
        if filename.root not in filename.parts:
            raise ValueError("Must be an absolute path.")

        parent = uuid.UUID(int=0)
        for part in filename.parts[1:]:
            metadata = self.__paths.tree.get(key=uuid.uuid5(parent, part))
            if not metadata:
                return None
            path = PathRecord.meta_unpack(metadata)
            if follow_link and path.type == TYPE_LINK:
                entry = self.__follow_link(path.id)
                parent = entry.parent
            else:
                parent = path.id

        return parent

    def create_entry(self, type_: bytes, name: str, parent: uuid.UUID = uuid.UUID(int=0), **kwargs) -> uuid.UUID:
        """Create a new entry: file, directory or link.

        Args:
            type_ (bytes):
                Type of entry
            name (str):
                Entry name
            parent (uuid.UUID):
                Parent entry UUID number
            **kwargs:
                The rest of the entry fields

        Returns (uuid.UUID):
            Entry UUID number

        """
        path_key = uuid.uuid5(parent, name)

        if self.__paths.tree.get(key=path_key) is not None:
            raise KeyError("Key already exists in paths")

        if type_ == TYPE_DIR:
            entry = EntryRecord.dir(name=name, parent=parent, **kwargs)
            self.__listings.tree.insert(key=entry.id, value=set())
        elif type_ == TYPE_FILE:
            entry = EntryRecord.file(name=name, parent=parent, **kwargs)
        elif type_ == TYPE_LINK:
            target = self.__entries.tree.get(key=kwargs.get("owner"))
            del kwargs["owner"]

            if target is None:
                raise OSError("Target of link doesn't exist")
            target = EntryRecord.meta_unpack(target)
            if target.type == TYPE_LINK:
                raise OSError("Target of a link must be file or directory, not another link")

            entry = EntryRecord.link(name=name, link=target.id, parent=parent, **kwargs)
        else:
            raise ValueError("Entry type is unknown")


        self.__entries.tree.insert(key=entry.id, value=bytes(entry))
        self.__paths.tree.insert(key=path_key, value=bytes(PathRecord.path(entry.type, entry.id)))
        self.__listings.tree.update(key=entry.parent, insertions=[entry.id.bytes])

        return entry.id

    def update_entry(
        self, identity: uuid.UUID, owner: uuid.UUID = None, modified: datetime.datetime = None,
        deleted: bool = None, user: str = None, group: str = None, perms: int = None
    ):
        """Update certain fields in a entry.

        Args:
            identity (uuid.UUID):
                Entry UUID number
            owner (uuid.UUID):
                Entry owner UUID number
            modified (datetime.datetime):
                New modified datetime
            deleted (bool):
                Deleted or not
            user (str):
                Unix user name
            group (str):
                Unix group name
            perms (int):
                Unix permissions

        """
        entry = EntryRecord.meta_unpack(self.__entries.tree.get(key=identity))

        if entry is None:
            raise KeyError("Entry doesn't exist")

        if owner:
            entry.owner = owner
        if modified:
            entry.modified = modified
        if deleted:
            entry.deleted = deleted
        if user:
            entry.user = user.encode("utf-8")[:32]
        if group:
            entry.group = group.encode("utf-8")[:16]
        if perms:
            entry.perms = min(0o777, max(0o000, perms))

        self.__entries.tree.update(key=entry.id, value=bytes(entry))

    def delete_entry(self, identity: uuid.UUID, delete: int):
        """Delete entry according to level.

        Args:
            identity (uuid.UUID):
                Entry UUID number
            delete (int):
                Delete level

        """
        entry = EntryRecord.meta_unpack(self.__entries.tree.get(key=identity))

        if entry is None:
            raise KeyError("Entry doesn't exist")

        if entry.type == TYPE_DIR:
            if self.__listings.tree.get(key=entry.id):
                raise OSError("Can't delete directory because of files")

        if delete == Delete.SOFT:
            entry.deleted = True
            self.__entries.tree.update(key=entry.id, value=bytes(entry))
        elif delete == Delete.HARD:
            entry.deleted = True
            if entry.stream.int != 0:
                self.del_stream(entry.stream)
                self.stream = None
            self.__entries.tree.update(key=entry.id, value=bytes(entry))
        elif delete == Delete.ERASE:
            if entry.stream.int != 0:
                self.del_stream(entry.stream)
                entry.stream = None

            self.__listings.tree.update(key=entry.parent, deletions=set(entry.id.bytes))
            self.__listings.tree.delete(key=entry.id)
            self.__paths.tree.delete(key=uuid.uuid5(entry.parent, entry.name.decode()))
            self.__entries.tree.delete(key=entry.id)
        else:
            raise ValueError("Delete level unknown")

    def search_entry(self, identity: uuid.UUID) -> EntryRecord:
        meta = self.__entries.tree.get(key=identity)
        if not meta:
            raise ValueError("No entry for %s" % identity)
        return EntryRecord.meta_unpack(meta)

    def change_parent(self, identity: uuid.UUID, parent: uuid.UUID):
        """Change parent of an entry i.e. changing directory.

        Args:
            identity (uuid.UUID):
                Entry UUID number
            parent (uuid.UUID):
                New parent UUID number

        """
        entry = EntryRecord.meta_unpack(self.__entries.tree.get(key=identity))
        if entry is None:
            raise KeyError("Entry doesn't exist")

        new_parent = EntryRecord.meta_unpack(self.__entries.tree.get(key=parent))
        if new_parent is None:
            raise KeyError("Parent entry doesn't exist")

        if new_parent.type != TYPE_DIR:
            raise OSError("New parent is not a directory")

        if self.__paths.tree.get(key=uuid.uuid5(parent, entry.name.decode())) is not None:
            raise KeyError("Key already exists in paths")

        self.__listings.tree.update(key=new_parent.id, insertions=[entry.id.bytes])
        self.__listings.tree.update(key=entry.parent, deletions=set([entry.id.bytes]))

        self.__paths.tree.insert(
            key=uuid.uuid5(new_parent.id, entry.name.decode()),
            value=bytes(PathRecord(entry.type, entry.id)))
        self.__paths.tree.delete(key=uuid.uuid5(entry.parent, entry.name.decode()))

        entry.parent = parent
        self.__entries.tree.update(key=entry.id, value=bytes(entry))

    def change_name(self, identity: uuid.UUID, name: str):
        """Change name of an entry.

        Args:
            identity (uuid.UUID):
                Entry UUID number
            name (str):
                New name to change to

        """
        entry = EntryRecord.meta_unpack(self.__entries.tree.get(key=identity))
        if entry is None:
            raise KeyError("Entry doesn't exist")

        path_key = uuid.uuid5(entry.parent, name)
        if self.__paths.tree.get(key=path_key) is not None:
            raise KeyError("Key already exists in paths")

        self.__paths.tree.insert(
            key=uuid.uuid5(entry.parent, name),
            value=bytes(PathRecord(entry.type, entry.id))
        )
        self.__paths.tree.delete(uuid.uuid5(entry.parent, entry.name.decode()))
        entry.name = name.encode("utf-8")[:256]
        self.__entries.tree.update(key=identity, value=bytes(entry))

    def open(self, identity: uuid.UUID, mode: str = "r") -> FileObject:
        """Open a file stream as a file object.

        Args:
            identity (uuid.UUID):
                File entry UUID number
            mode (str):
                File mode

        Returns (VirtualFileObject):
            The opened file object

        """
        if identity in self.__descriptors.keys():
            raise OSError("File already open.")

        entry = EntryRecord.meta_unpack(self.__entries.tree.get(key=identity))

        if not entry.type == TYPE_FILE:
            raise OSError("Record not of type file.")

        if entry.deleted:
            raise OSError("Record is considered deleted.")

        if entry.stream.int == 0:
            stream = self.new_stream()
            entry.stream = stream.identity
            self.__entries.tree.update(key=entry.id, value=bytes(entry))
        else:
            stream = self.open_stream(entry.stream)

        vfd = FileObject(identity, stream, entry.name.decode(), mode)

        self.__descriptors[identity] = vfd
        return vfd

    def release(self, fd: FileObject):
        """Release a FileObject on close.

        Never call this method from outside a FileObject.

        Args:
            fd (FileObject):
                Open file object

        """
        number = fd.fileno()
        if fd.fileno() in self.__descriptors.keys():
            del self.__descriptors[number]

    def traverse_hierarchy(self, directory: uuid.UUID) -> Iterator:
        """Iterator that traverses the hierarchy.
        
        Iterates over the listing of a directory and traverses down each directory.
        This iterator uses the listings to iterate over a directory, then yealds each entry.
        
        Args:
            directory (uuid.UUID): 
                Directory entry UUID number

        Returns (Iterator):
            Iterator that traverses the hierarchy
        """
        return iter(HierarchyTraverser(directory, self.__entries, self.__paths, self.__listings))


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