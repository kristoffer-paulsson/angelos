# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Archive 7.

In future C implementation, use BTree for entries:
https://github.com/antirez/otree
"""
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

from ..ioc import Container, ContainerAware
from ..utils import Util
from ..error import Error
from .conceal import ConcealIO


class Header(
    collections.namedtuple(
        "Header",
        field_names=[
            "major",  # 2
            "minor",  # 2
            "type",  # 1  # Facade type
            "role",  # 1  # Role in the domain network
            "use",  # 1  # Purpose of the archive
            "id",  # 16
            "owner",  # 16
            "domain",  # 16
            "node",  # 16
            "created",  # 8
            "title",  # 128
            "entries",  # 4
        ],
        defaults=(
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
        ),
    )
):
    """Archive header."""

    __slots__ = ()
    FORMAT = "!8sHHbbb16s16s16s16sQ128sL805x"

    @staticmethod
    def header(
        owner,
        id=None,
        node=None,
        domain=None,
        title=None,
        _type=None,
        role=None,
        use=None,
        major=1,
        minor=0,
        entries=8,
    ):
        """Generate archive header."""
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
            entries=entries,
        )

    def serialize(self):
        """Serialize archive header."""
        return struct.pack(
            Header.FORMAT,
            b"archive7",
            1,
            0,
            self.type if not isinstance(self.type, type(None)) else 0,
            self.role if not isinstance(self.role, type(None)) else 0,
            self.use if not isinstance(self.use, type(None)) else 0,
            self.id.bytes
            if isinstance(self.id, uuid.UUID)
            else uuid.uuid4().bytes,
            self.owner.bytes
            if isinstance(self.owner, uuid.UUID)
            else b"\x00" * 16,
            self.domain.bytes
            if isinstance(self.domain, uuid.UUID)
            else b"\x00" * 16,
            self.node.bytes
            if isinstance(self.node, uuid.UUID)
            else b"\x00" * 16,
            int(
                time.mktime(self.created.timetuple())
                if isinstance(self.created, datetime.datetime)
                else time.mktime(datetime.datetime.now().timetuple())
            ),
            self.title[:64]
            if isinstance(self.title, (bytes, bytearray))
            else b"\x00" * 64,
            self.entries if isinstance(self.entries, int) else 8,
        )

    @staticmethod
    def deserialize(data):
        """Deserialize archive header."""
        Util.is_type(data, (bytes, bytearray))
        t = struct.unpack(Header.FORMAT, data)

        if t[0] != b"archive7":
            raise Util.exception(Error.AR7_INVALID_FORMAT, {"format": t[0]})

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
            title=t[11].strip(b"\x00"),
            entries=t[12],
        )


class Entry(
    collections.namedtuple(
        "Entry",
        field_names=[
            "type",  # 1
            "id",  # 16
            "parent",  # 16
            "owner",  # 16
            "created",  # 8
            "modified",  # 8
            "offset",  # 8
            "size",  # 8
            "length",  # 8
            "compression",  # 1
            "deleted",  # 1
            "digest",  # 20
            "name",  # 64
            # Unix extras
            "user",  # 32
            "group",  # 16
            "perms",  # 2
            # padding       # 2
            # blanks        # 29
        ],
        defaults=(
            b"b",
            uuid.uuid4(),  # Always generate manually
            uuid.UUID(bytes=b"\x00" * 16),
            uuid.UUID(bytes=b"\x00" * 16),
            datetime.datetime.fromtimestamp(0),  # Always generate manually
            datetime.datetime.fromtimestamp(0),  # Always generate manually
            None,
            None,
            None,
            0,
            False,
            None,
            None,
            # Unix extras
            None,
            None,
            755,
        ),
    )
):
    """Archive entry header."""

    __slots__ = ()

    FORMAT = "!c16s16s16sqqQQQb?20s64s32s16sH2x29x"
    TYPE_FILE = b"f"  # Represents a file
    TYPE_LINK = b"l"  # Represents a link
    TYPE_DIR = b"d"  # Represents a directory
    TYPE_EMPTY = b"e"  # Represents an empty block
    TYPE_BLANK = b"b"  # Represents an empty entry
    COMP_NONE = 0
    COMP_ZIP = 1
    COMP_GZIP = 2
    COMP_BZIP2 = 3

    @staticmethod
    def blank():
        """Generate a blank ready-to-use entry header."""
        kwargs = {"type": Entry.TYPE_BLANK, "id": uuid.uuid4()}
        return Entry(**kwargs)

    @staticmethod
    def empty(offset, size):
        """Generate header for a block of reusable space."""
        Util.is_type(offset, int)
        Util.is_type(size, int)

        kwargs = {
            "type": Entry.TYPE_EMPTY,
            "id": uuid.uuid4(),
            "offset": offset,
            "size": size,
        }
        return Entry(**kwargs)

    @staticmethod
    def dir(
        name,
        parent=None,
        owner=None,
        created=None,
        modified=None,
        user=None,
        group=None,
        perms=None,
    ):
        """Generate entry for a directory."""
        Util.is_type(name, str)
        Util.is_type(parent, (type(None), uuid.UUID))
        Util.is_type(owner, (type(None), uuid.UUID))
        Util.is_type(created, (type(None), datetime.datetime))
        Util.is_type(modified, (type(None), datetime.datetime))
        Util.is_type(user, (type(None), str))
        Util.is_type(group, (type(None), str))
        Util.is_type(perms, (type(None), int))

        kwargs = {
            "type": Entry.TYPE_DIR,
            "id": uuid.uuid4(),
            "created": datetime.datetime.now(),
            "modified": datetime.datetime.now(),
            "name": name.encode("utf-8")[:64],
        }

        if parent:
            kwargs["parent"] = parent
        if owner:
            kwargs["owner"] = owner
        if created:
            kwargs["created"] = created
        if modified:
            kwargs["modified"] = modified
        if user:
            kwargs["user"] = user.encode("utf-8")[:32]
        if group:
            kwargs["group"] = group.encode("utf-8")[:16]
        if perms:
            kwargs["perms"] = perms

        return Entry(**kwargs)

    @staticmethod
    def link(
        name,
        link,
        parent=None,
        created=None,
        modified=None,
        user=None,
        group=None,
        perms=None,
    ):
        """Generate entry for file link."""
        Util.is_type(name, str)
        Util.is_type(parent, (type(None), uuid.UUID))
        Util.is_type(link, uuid.UUID)
        Util.is_type(created, (type(None), datetime.datetime))
        Util.is_type(modified, (type(None), datetime.datetime))
        Util.is_type(user, (type(None), str))
        Util.is_type(group, (type(None), str))
        Util.is_type(perms, (type(None), int))

        kwargs = {
            "type": Entry.TYPE_LINK,
            "id": uuid.uuid4(),
            "owner": link,
            "created": datetime.datetime.now(),
            "modified": datetime.datetime.now(),
            "name": name.encode("utf-8")[:64],
        }

        if parent:
            kwargs["parent"] = parent
        if created:
            kwargs["created"] = created
        if modified:
            kwargs["modified"] = modified
        if user:
            kwargs["user"] = user.encode("utf-8")[:32]
        if group:
            kwargs["group"] = group.encode("utf-8")[:16]
        if perms:
            kwargs["perms"] = perms

        return Entry(**kwargs)

    @staticmethod
    def file(
        name,
        offset,
        size,
        digest,
        id=None,
        parent=None,
        owner=None,
        created=None,
        modified=None,
        compression=None,
        length=None,
        user=None,
        group=None,
        perms=None,
    ):
        """Entry header for file."""
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
        Util.is_type(user, (type(None), str))
        Util.is_type(group, (type(None), str))
        Util.is_type(perms, (type(None), int))

        kwargs = {
            "type": Entry.TYPE_FILE,
            "id": uuid.uuid4(),
            "created": datetime.datetime.now(),
            "modified": datetime.datetime.now(),
            "offset": offset,
            "size": size,
            "digest": digest[:20],
            "name": name.encode("utf-8")[:64],
        }

        if id:
            kwargs["id"] = id
        if parent:
            kwargs["parent"] = parent
        if owner:
            kwargs["owner"] = owner
        if created:
            kwargs["created"] = created
        if modified:
            kwargs["modified"] = modified
        if user:
            kwargs["user"] = user.encode("utf-8")[:32]
        if group:
            kwargs["group"] = group.encode("utf-8")[:16]
        if perms:
            kwargs["perms"] = perms
        if compression and length:
            if 1 <= compression <= 3 and not isinstance(length, int):
                raise Util.exception(
                    Error.AR7_INVALID_COMPRESSION, {"compression": compression}
                )
            kwargs["compression"] = compression
            kwargs["length"] = length
        else:
            kwargs["length"] = size

        return Entry(**kwargs)

    def serialize(self):
        """Serialize entry."""
        return struct.pack(
            Entry.FORMAT,
            self.type
            if not isinstance(self.type, type(None))
            else Entry.TYPE_BLANK,
            self.id.bytes
            if isinstance(self.id, uuid.UUID)
            else uuid.uuid4().bytes,
            self.parent.bytes
            if isinstance(self.parent, uuid.UUID)
            else b"\x00" * 16,
            self.owner.bytes
            if isinstance(self.owner, uuid.UUID)
            else b"\x00" * 16,
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
            self.offset if isinstance(self.offset, int) else 0,
            self.size if isinstance(self.size, int) else 0,
            self.length if isinstance(self.length, int) else 0,
            self.compression
            if isinstance(self.compression, int)
            else Entry.COMP_NONE,
            self.deleted if isinstance(self.deleted, bool) else False,
            # b'\x00'*17,
            self.digest
            if isinstance(self.digest, (bytes, bytearray))
            else b"\x00" * 20,
            self.name[:64]
            if isinstance(self.name, (bytes, bytearray))
            else b"\x00" * 64,
            self.user[:32]
            if isinstance(self.user, (bytes, bytearray))
            else b"\x00" * 32,
            self.group[:16]
            if isinstance(self.group, (bytes, bytearray))
            else b"\x00" * 16,
            self.perms if isinstance(self.perms, int) else 755,
        )

    @staticmethod
    def deserialize(data):
        """Deserialize entry."""
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
            name=t[12].strip(b"\x00"),
            user=t[13].strip(b"\x00"),
            group=t[14].strip(b"\x00"),
            perms=int(t[15]),
        )


class Archive7(ContainerAware):
    """Archive main class and high level API."""

    BLOCK_SIZE = 512

    def __init__(self, fileobj, delete=3):
        """Init archive using a file object and set delete mode."""
        self.__closed = False
        self.__lock = threading.Lock()
        self.__file = fileobj
        self.__size = os.path.getsize(self.__file.name)
        self.__delete = delete if delete else Archive7.Delete.ERASE
        self.__file.seek(0)
        self.__header = Header.deserialize(
            self.__file.read(struct.calcsize(Header.FORMAT))
        )

        offset = self.__file.seek(1024)
        if offset != 1024:
            raise Util.exception(Error.AR7_INVALID_SEEK, {"position": offset})

        entries = []
        for i in range(self.__header.entries):
            entries.append(
                Entry.deserialize(
                    self.__file.read(struct.calcsize(Entry.FORMAT))
                )
            )

        ContainerAware.__init__(
            self,
            Container(
                config={
                    "archive": lambda s: self,
                    "entries": lambda s: Archive7.Entries(s, entries),
                    "hierarchy": lambda s: Archive7.Hierarchy(s),
                    "operations": lambda s: Archive7.Operations(s),
                    "fileobj": lambda s: self.__file,
                }
            ),
        )

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    @staticmethod
    def setup(
        filename,
        secret,
        owner=None,
        node=None,
        title=None,
        domain=None,
        _type=None,
        role=None,
        use=None,
    ):
        """Create a new archive."""
        Util.is_type(filename, (str, bytes))
        Util.is_type(secret, (str, bytes))

        with ConcealIO(filename, "wb", secret=secret):
            pass
        fileobj = ConcealIO(filename, "rb+", secret=secret)

        header = Header.header(
            owner=owner,
            node=node,
            title=str(title).encode(),
            domain=domain,
            _type=_type,
            role=role,
            use=use,
        )

        fileobj.write(header.serialize())
        for i in range(header.entries):
            fileobj.write(Entry.blank().serialize())
        fileobj.seek(0)

        return Archive7(fileobj)

    @staticmethod
    def open(filename, secret, delete=3, mode="rb+"):
        """Open an archive with a symmetric encryption key."""
        Util.is_type(filename, (str, bytes))
        Util.is_type(secret, (str, bytes))

        if not os.path.isfile(filename):
            raise Util.exception(Error.AR7_NOT_FOUND, {"path": filename})

        fileobj = ConcealIO(filename, mode, secret=secret)
        return Archive7(fileobj, delete)

    @property
    def closed(self):
        """File closed property."""
        return self.__closed

    @property
    def locked(self):
        """Lock mode property."""
        return self.__lock.locked()

    @property
    def lock(self):
        """Lock property."""
        return self.__lock

    def _update_header(self, cnt):
        """Update archive header with new entries count."""
        header = self.__header._asdict()
        header["entries"] = cnt
        self.__header = Header(**header)
        self.ioc.operations.write_data(0, self.__header.serialize())

    def close(self):
        """Close archive."""
        with self.__lock:
            if not self.__closed:
                self.__file.close()
                self.__closed = True

    def stats(self):
        """Archive stats."""
        return copy.deepcopy(self.__header)

    def info(self, filename):
        """Return file info."""
        with self.__lock:
            ops = self.ioc.operations

            dirname, name = os.path.split(filename)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)

            return copy.deepcopy(entry)

    def glob(
        self,
        name="*",
        id=None,
        parent=None,
        owner=None,
        created=None,
        modified=None,
        deleted=False,
        user=None,
        group=None,
    ):
        """Glob the file system in the archive."""
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
            if user:
                sq.user(user)
            if group:
                sq.group(group)
            idxs = entries.search(sq)

            files = []
            for i in idxs:
                idx, entry = i
                if entry.parent.int == 0:
                    name = "/" + str(entry.name, "utf-8")
                else:
                    name = ids[entry.parent] + "/" + str(entry.name, "utf-8")
                files.append(name)

            return files

    def move(self, src, dest):
        """Move file/dir to another directory."""
        with self.__lock:
            ops = self.ioc.operations

            dirname, name = os.path.split(src)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)
            did = ops.get_pid(dest)
            ops.is_available(name, did)

            entry = entry._asdict()
            entry["parent"] = did
            entry = Entry(**entry)
            self.ioc.entries.update(entry, idx)

    def chmod(
        self,
        path,
        id=None,
        owner=None,
        deleted=None,
        user=None,
        group=None,
        perms=None,
    ):
        """Update ID/owner or deleted status for an entry."""
        with self.__lock:
            ops = self.ioc.operations

            dirname, name = os.path.split(path)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)

            entry = entry._asdict()
            if id:
                entry["id"] = id
            if owner:
                entry["owner"] = owner
            if deleted:
                entry["deleted"] = deleted
            if user:
                entry["user"] = user
            if group:
                entry["group"] = group
            if perms:
                entry["perms"] = perms
            entry = Entry(**entry)
            self.ioc.entries.update(entry, idx)

    def remove(self, filename, mode=None):
        """Remove file or dir."""
        with self.__lock:
            ops = self.ioc.operations
            entries = self.ioc.entries

            dirname, name = os.path.split(filename)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)

            # Check for unsupported types
            if entry.type not in (
                Entry.TYPE_FILE,
                Entry.TYPE_DIR,
                Entry.TYPE_LINK,
            ):
                raise Util.exception(
                    Error.AR7_WRONG_ENTRY, {"type": entry.type, "id": entry.id}
                )

            # If directory is up for removal, check that it is empty or abort
            if entry.type == Entry.TYPE_DIR:
                cidx = entries.search(Archive7.Query().parent(entry.id))
                if len(cidx):
                    raise Util.exception(Error.AR7_NOT_EMPTY, {"index": cidx})

            if not mode:
                mode = self.__delete

            if mode == Archive7.Delete.ERASE:
                if entry.type == Entry.TYPE_FILE:
                    entries.update(
                        Entry.empty(
                            offset=entry.offset,
                            size=entries._sector(entry.size),
                        ),
                        idx,
                    )
                elif entry.type in (Entry.TYPE_DIR, Entry.TYPE_LINK):
                    entries.update(Entry.blank(), idx)
            elif mode == Archive7.Delete.SOFT:
                entry = entry._asdict()
                entry["deleted"] = True
                entry["modified"] = datetime.datetime.now()
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
                            size=entries._sector(entry.size),
                        ),
                        bidx,
                    )
                    entry = entry._asdict()
                    entry["deleted"] = True
                    entry["modified"] = datetime.datetime.now()
                    entry["size"] = 0
                    entry["length"] = 0
                    entry["offset"] = 0
                    entry = Entry(**entry)
                    self.ioc.entries.update(entry, idx)
                elif entry.type in (Entry.TYPE_DIR, Entry.TYPE_LINK):
                    entry = entry._asdict()
                    entry["deleted"] = True
                    entry["modified"] = datetime.datetime.now()
                    entry = Entry(**entry)
                    self.ioc.entries.update(entry, idx)
            else:
                raise Util.exception(
                    Error.AR7_INVALID_DELMODE, {"mode": self.__delete}
                )

    def rename(self, path, dest):
        """Rename file or directory."""
        with self.__lock:
            ops = self.ioc.operations
            entries = self.ioc.entries

            dirname, name = os.path.split(path)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)
            ops.is_available(dest, pid)

            entry = entry._asdict()
            entry["name"] = bytes(dest, "utf-8")
            entry = Entry(**entry)
            entries.update(entry, idx)

    def isdir(self, dirname):
        """Check if a path is a known directory."""
        if dirname[0] is not "/":
            dirname = "/" + dirname
        if dirname[-1] is "/":
            dirname = dirname[:-1]
        return dirname in self.ioc.hierarchy.paths.keys()

    def isfile(self, filename):
        """Check if a path is a known file."""
        with self.__lock:
            try:
                ops = self.ioc.operations

                dirname, name = os.path.split(filename)
                pid = ops.get_pid(dirname)
                entry, idx = ops.find_entry(name, pid)
                if entry.type == Entry.TYPE_FILE:
                    return True
            except Exception:
                pass

        return False

    def mkdir(self, dirname, user=None, group=None, perms=None):
        """
        Make a new directory and super directories if missing.

            name        The full path and name of new directory
            returns     the entry ID
        """
        with self.__lock:
            paths = self.ioc.hierarchy.paths

            if dirname in paths.keys():
                return paths[dirname]

            subpath = []
            while len(dirname) and dirname not in paths.keys():
                dirname, name = os.path.split(dirname)
                subpath.append(name)

            subpath.reverse()
            pid = paths[dirname]
            entries = self.ioc.entries

            for newdir in subpath:
                entry = Entry.dir(
                    name=name, parent=pid, user=user, group=group, perms=perms
                )
                entries.add(entry)
                pid = entry.id

        return entry.id

    def mkfile(
        self,
        filename,
        data,
        created=None,
        modified=None,
        owner=None,
        parent=None,
        id=None,
        compression=Entry.COMP_NONE,
        user=None,
        group=None,
        perms=None,
    ):
        """Create a new file."""
        with self.__lock:
            ops = self.ioc.operations
            dirname, name = os.path.split(filename)
            pid = None

            if parent:
                ids = self.ioc.hierarchy.ids
                if parent not in ids.keys():
                    raise Util.exception(
                        Error.AR7_PATH_INVALID, {"parent": parent}
                    )
                pid = parent
            elif dirname:
                pid = ops.get_pid(dirname)

            ops.is_available(name, pid)

            length = len(data)
            digest = hashlib.sha1(data).digest()
            if compression and data:
                data = ops.zip(data, compression)
            size = len(data)

            entry = Entry.file(
                name=name,
                size=size,
                offset=0,
                digest=digest,
                id=id,
                parent=pid,
                owner=owner,
                created=created,
                modified=modified,
                length=length,
                compression=compression,
                user=user,
                group=group,
                perms=perms,
            )

        return self.ioc.entries.add(entry, data)

    def link(
        self,
        path,
        link,
        created=None,
        modified=None,
        user=None,
        group=None,
        perms=None,
    ):
        """Create a new link to file or directory."""
        with self.__lock:
            ops = self.ioc.operations
            dirname, name = os.path.split(path)
            pid = ops.get_pid(dirname)
            ops.is_available(name, pid)

            ldir, lname = os.path.split(link)
            lpid = ops.get_pid(ldir)
            target, tidx = ops.find_entry(lname, lpid)

            if target.type == Entry.TYPE_LINK:
                raise Util.exception(
                    Error.AR7_LINK_2_LINK, {"path": path, "link": target}
                )

            entry = Entry.link(
                name=name,
                link=target.id,
                parent=pid,
                created=created,
                modified=modified,
                user=user,
                group=group,
                perms=perms,
            )

        return self.ioc.entries.add(entry)

    def save(self, filename, data, compression=Entry.COMP_NONE, modified=None):
        """Update a file with new data."""
        if not modified:
            modified = datetime.datetime.now()

        with self.__lock:
            ops = self.ioc.operations
            entries = self.ioc.entries

            if not entries.find_blank():
                entries.make_blanks()

            dirname, name = os.path.split(filename)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(
                name, pid, (Entry.TYPE_FILE, Entry.TYPE_LINK)
            )

            if entry.type == Entry.TYPE_LINK:
                entry, idx = ops.follow_link(entry)

            length = len(data)
            digest = hashlib.sha1(data).digest()
            if compression and data:
                data = ops.zip(data, compression)
            size = len(data)

            osize = entries._sector(entry.size)
            nsize = entries._sector(size)

            if osize < nsize:
                empty = Entry.empty(offset=entry.offset, size=osize)
                last = entries.get_entry(entries.get_thithermost())
                new_offset = entries._sector(last.offset + last.size)
                ops.write_data(new_offset, data + ops.filler(data))

                entry = entry._asdict()
                entry["digest"] = digest
                entry["offset"] = new_offset
                entry["size"] = size
                entry["length"] = length
                entry["modified"] = modified
                entry["compression"] = compression
                entry = Entry(**entry)
                entries.update(entry, idx)

                bidx = entries.get_blank()
                entries.update(empty, bidx)
            elif osize == nsize:
                ops.write_data(entry.offset, data + ops.filler(data))

                entry = entry._asdict()
                entry["digest"] = digest
                entry["size"] = size
                entry["length"] = length
                entry["modified"] = modified
                entry["compression"] = compression
                entry = Entry(**entry)
                entries.update(entry, idx)
            elif osize > nsize:
                ops.write_data(entry.offset, data + ops.filler(data))
                old_offset = entry.offset

                entry = entry._asdict()
                entry["digest"] = digest
                entry["size"] = size
                entry["length"] = length
                entry["modified"] = modified
                entry["compression"] = compression
                if not size:  # If data is b''
                    entry["offset"] = 0
                entry = Entry(**entry)
                entries.update(entry, idx)

                empty = Entry.empty(
                    offset=entries._sector(old_offset + nsize),
                    size=osize - nsize,
                )
                bidx = entries.get_blank()
                entries.update(empty, bidx)

    def load(self, filename):
        """Load data from a file."""
        with self.__lock:
            ops = self.ioc.operations

            dirname, name = os.path.split(filename)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(
                name, pid, (Entry.TYPE_FILE, Entry.TYPE_LINK)
            )

            if entry.type == Entry.TYPE_LINK:
                entry, idx = ops.follow_link(entry)

            data = self.ioc.operations.load_data(entry)

            if entry.compression and data:
                data = ops.unzip(data, entry.compression)

            if entry.digest != hashlib.sha1(data).digest():
                raise Util.exception(
                    Error.AR7_DIGEST_INVALID,
                    {"filename": filename, "id": entry.id},
                )

            return data

    class Entries(ContainerAware):
        """Entries manager."""

        def __init__(self, ioc, entries):
            """Init entry manager."""
            ContainerAware.__init__(self, ioc)
            self.reload()

        def reload(self):
            """Reload all entries from archive."""
            entries = []
            length = struct.calcsize(Entry.FORMAT)
            header = self.ioc.archive.stats()
            fileobj = self.ioc.fileobj
            fileobj.seek(1024)

            for i in range(header.entries):
                entries.append(Entry.deserialize(fileobj.read(length)))

            self.__all = entries
            self.__files = [
                i
                for i in range(len(entries))
                if entries[i].type == Entry.TYPE_FILE
            ]
            self.__links = [
                i
                for i in range(len(entries))
                if entries[i].type == Entry.TYPE_LINK
            ]
            self.__dirs = [
                i
                for i in range(len(entries))
                if entries[i].type == Entry.TYPE_DIR
            ]
            self.__empties = [
                i
                for i in range(len(entries))
                if entries[i].type == Entry.TYPE_EMPTY
            ]
            self.__blanks = [
                i
                for i in range(len(entries))
                if entries[i].type == Entry.TYPE_BLANK
            ]

        def _sector(self, length):
            return int(math.ceil(length / 512) * 512)

        def get_entry(self, index):
            """Return entry based on index."""
            return self.__all[index]

        def get_empty(self, size):
            """Return entry index for largest empty block, large enough."""
            if not size:
                return None

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
            Return a blank entry to use.

            Don't use this function if you intend to not use the entry.
            Otherwise the hierarchy will become corrupt.
            Returns     index or None
            """
            if len(self.__blanks) >= 1:
                return self.__blanks.pop(0)
            else:
                return None

        def find_blank(self, num=1):
            """
            Find a number of available blank entries in the hierarchy.

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
            Create more blank entries.

            Allocates space in the beginning of the archive.
            num     Number of new blanks
            """
            cnt = 0
            space = 0
            need = max(num, 8) * 256
            length = len(self.__all) * 256 + 1024
            hithermost = None
            nempty = None

            while space < need:
                idx = self.get_hithermost()
                if idx is None:
                    space = need
                    continue

                hithermost = self.__all[idx]
                if hithermost.type not in (Entry.TYPE_EMPTY, Entry.TYPE_FILE):
                    raise Util.exception(Error.AR7_BLANK_FAILURE)

                if hithermost.type == Entry.TYPE_EMPTY:
                    empty = hithermost
                if hithermost.type == Entry.TYPE_FILE:
                    empty = self.ioc.operations.move_end(idx)

                total = self._sector(empty.offset + empty.size) - length
                if hithermost.type == Entry.TYPE_EMPTY:
                    if total >= (need + 512):
                        entry = hithermost._asdict()
                        entry["offset"] = self._sector(length + need)
                        entry["size"] = self._sector(total - need)
                        entry = Entry(**entry)
                        self.update(entry, idx)
                        space = need
                    else:
                        self.update(Entry.blank(), idx)
                        space = total

                if hithermost.type == Entry.TYPE_FILE:
                    if total >= (need + 512):
                        entry = empty._asdict()
                        entry["offset"] = self._sector(length + need)
                        entry["size"] = self._sector(total - need)
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
            """Return entry index for file closest to the beginning."""
            idx = None
            offset = sys.maxsize

            idxs = set(self.__files + self.__empties)
            for i in idxs:
                if offset > self.__all[i].offset > limit:
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def get_thithermost(self, limit=sys.maxsize):
            """Return entry index for file closest to the end."""
            idx = None
            offset = 0

            idxs = set(self.__files + self.__empties)
            for i in idxs:
                if offset < self.__all[i].offset < limit:
                    idx = i
                    offset = self.__all[i].offset

            return idx

        def update(self, entry, index):
            """Update entry, save it and keep hierachy clean."""
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
                    raise OSError("Unknown entry type", old.type)

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
                    raise OSError("Unknown entry type", entry.type)

            elif entry.type == Entry.TYPE_DIR:
                self.ioc.hierarchy.remove(old)
                self.ioc.hierarchy.add(entry)

            self.__all[index] = entry
            self.ioc.operations.write_entry(entry, index)

        def add(self, entry, data=None):
            """Add file entry to hierarchy and save data."""
            if not self.find_blank():
                self.make_blanks()

            if entry.type in [Entry.TYPE_DIR, Entry.TYPE_LINK]:
                bidx = self.get_blank()
                self.update(entry, bidx)

            elif entry.type == Entry.TYPE_FILE:
                if isinstance(data, type(None)):
                    raise Util.exception(
                        Error.AR7_DATA_MISSING, {"id": entry.id}
                    )
                space = self._sector(len(data))
                eidx = self.get_empty(space)
                if isinstance(eidx, int):
                    empty = self.__all[eidx]
                    offset = empty.offset
                    if empty.size > space:
                        empty = empty._asdict()
                        empty["offset"] = offset + space
                        empty["size"] = self._sector(empty["size"] - space)
                        empty = Entry(**empty)
                        self.update(empty, eidx)
                    else:
                        self.update(Entry.blank(), eidx)
                elif not data:
                    offset = 0
                elif (len(self.__files) + len(self.__empties)) > 0:
                    last = self.__all[self.get_thithermost()]
                    offset = self._sector(last.offset + last.size)
                else:
                    offset = self._sector(1024 + len(self.__all) * 256)

                entry = entry._asdict()
                entry["offset"] = offset
                entry = Entry(**entry)

                ops = self.ioc.operations
                if data:
                    ops.write_data(offset, data + ops.filler(data))
                bidx = self.get_blank()
                self.update(entry, bidx)
            else:
                raise Util.exception(
                    Error.AR7_WRONG_ENTRY, {"type": entry.type, "id": entry.id}
                )

            return True

        def search(self, query, raw=False):
            """Search with a query."""
            Util.is_type(query, Archive7.Query)
            filterator = filter(
                query.build(self.ioc.hierarchy.paths), enumerate(self.__all)
            )
            if not raw:
                return list(filterator)
            else:
                return filterator

        def follow(self, entry):
            """Follow link and return entries indices."""
            if entry.type != Entry.TYPE_LINK:
                raise Util.exception(
                    Error.AR7_WRONG_ENTRY, {"type": entry.type, "id": entry.id}
                )
            query = Archive7.Query().id(entry.owner)
            return list(filter(query.build(), enumerate(self.__all)))

        @property
        def count(self):
            """Length of entry list."""
            return len(self.__all)

        @property
        def files(self):
            """List with all file entries."""
            return self.__files

        @property
        def links(self):
            """List with all link entries."""
            return self.__links

        @property
        def dirs(self):
            """List with all directory entries."""
            return self.__dirs

        @property
        def empties(self):
            """List with all emtpy entries."""
            return self.__empties

        @property
        def blanks(self):
            """List with all blank entries."""
            return self.__blanks

    class Hierarchy(ContainerAware):
        """Path hierarchy manager."""

        def __init__(self, ioc):
            """Init hierarchy manager."""
            ContainerAware.__init__(self, ioc)
            self.reload()

        def _build(self):
            pass

        def reload(self, deleted=False):
            """Reload hierachy from entries manager."""
            entries = self.ioc.entries
            dirs = entries.dirs
            zero = uuid.UUID(bytes=b"\x00" * 16)
            self.__paths = {"/": zero}
            self.__ids = {zero: "/"}

            for i in range(len(dirs)):
                path = []
                search_path = ""
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
                        raise Util.exception(
                            Error.AR7_PATH_BROKEN, {"id": current.id}
                        )

                    current = parent
                    path.append(current)

                search_path = ""
                path.reverse()
                for j in range(len(path)):
                    search_path += "/" + str(path[j].name, "utf-8")

                self.__paths[search_path] = cid
                self.__ids[cid] = search_path

        def add(self, entry, deleted=False):
            """Add directory entry to hierarchy."""
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
                    raise Util.exception(
                        Error.AR7_PATH_BROKEN, {"id": current.id}
                    )

                current = parent
                path.append(current)

            search_path = ""
            path.reverse()
            for j in range(len(path)):
                search_path += "/" + str(path[j].name, "utf-8")

            self.__paths[search_path] = cid
            self.__ids[cid] = search_path

        def remove(self, entry):
            """Remove directory entry from hierarchy."""
            path = self.__ids[entry.id]
            del self.__paths[path]
            del self.__ids[entry.id]

        @property
        def paths(self):
            """Map of path to id."""
            return self.__paths

        @property
        def ids(self):
            """Map of id to path."""
            return self.__ids

    class Operations(ContainerAware):
        """Logical operations on data and archive."""

        def filler(self, data):
            """
            Generate filler data to make even with a length of 512 bytes.

            If data is empty (b'') this method must return b''!
            """
            length = len(data)
            return b"\x00" * (int(math.ceil(length / 512) * 512) - length)

        def get_pid(self, dirname):
            """Get parent ID for directory."""
            paths = self.ioc.hierarchy.paths
            if dirname not in paths.keys():
                raise Util.exception(
                    Error.AR7_INVALID_DIR, {"dirname": dirname}
                )
            return paths[dirname]

        def follow_link(self, entry):
            """Return index of entry that link points at."""
            idxs = self.ioc.entries.follow(entry)
            if not len(idxs):
                raise Util.exception(Error.AR7_LINK_BROKEN, {"id": entry.id})
            else:
                idx, link = idxs.pop(0)
                if link.type != Entry.TYPE_FILE:
                    raise Util.exception(
                        Error.AR7_WRONG_ENTRY,
                        {"id": entry.id, "link": link.id},
                    )
            return link, idx

        def find_entry(self, name, pid, types=None):
            """Return entry for filename with parent ID."""
            entries = self.ioc.entries
            idx = entries.search(
                Archive7.Query(pattern=name)
                .parent(pid)
                .type(types)
                .deleted(False)
            )
            if not len(idx):
                raise Util.exception(
                    Error.AR7_INVALID_FILE, {"name": name, "pid": pid}
                )
            else:
                idx, entry = idx.pop(0)
            return entry, idx

        def write_entry(self, entry, index):
            """Write entry to disk."""
            Util.is_type(entry, Entry)
            Util.is_type(index, int)

            offset = index * 256 + 1024
            fileobj = self.ioc.fileobj
            if offset != fileobj.seek(offset):
                raise Util.exception(
                    Error.AR7_INVALID_SEEK, {"position": offset}
                )

            fileobj.write(entry.serialize())

        def load_data(self, entry):
            """Read data belonging to entry from disk."""
            if not entry.size:
                return b""
            if entry.type != Entry.TYPE_FILE:
                raise Util.exception(
                    Error.AR7_WRONG_ENTRY, {"type": entry.type, "id": entry.id}
                )
            fileobj = self.ioc.fileobj
            if fileobj.seek(entry.offset) != entry.offset:
                raise Util.exception(
                    Error.AR7_INVALID_SEEK, {"position": entry.offset}
                )
            return fileobj.read(entry.size)

        def write_data(self, offset, data):
            """Write data to disk."""
            if not len(data):
                return
            fileobj = self.ioc.fileobj
            if fileobj.seek(offset) != offset:
                raise Util.exception(
                    Error.AR7_INVALID_SEEK, {"position": offset}
                )
            fileobj.write(data)

        def move_end(self, idx):
            """
            Copy data for a file to the end of the archive.

            idx         Index of entry
            returns     Non-registered empty entry
            """
            entries = self.ioc.entries
            entry = entries.get_entry(idx)
            if not entry.type == Entry.TYPE_FILE:
                raise Util.exception(
                    Error.AR7_WRONG_ENTRY, {"type": entry.type, "id": entry.id}
                )

            last = entries.get_entry(entries.get_thithermost())
            data = self.load_data(entry)
            noffset = entries._sector(last.offset + last.size)
            self.write_data(noffset, data + self.filler(data))
            empty = Entry.empty(entry.offset, entries._sector(entry.size))

            entry = entry._asdict()
            entry["offset"] = noffset
            entry = Entry(**entry)
            entries.update(entry, idx)

            return empty

        def check(self, entry, data):
            """Calculate data integrity."""
            return entry.digest == hashlib.sha1(data).digest()

        def is_available(self, name, pid):
            """Check if filename is available in directory."""
            idx = self.ioc.entries.search(
                Archive7.Query(pattern=name).parent(pid).deleted(False)
            )
            if len(idx):
                raise Util.exception(
                    Error.AR7_NAME_TAKEN,
                    {"name": name, "pid": pid, "index": idx},
                )
            return True

        def zip(self, data, compression):
            """Compress data using a zip format."""
            if compression == Entry.COMP_ZIP:
                return zlib.compress(data)
            elif compression == Entry.COMP_GZIP:
                return gzip.compress(data)
            elif compression == Entry.COMP_BZIP2:
                return bz2.compress(data)
            else:
                raise Util.exception(
                    Error.AR7_INVALID_COMPRESSION, {"compression": compression}
                )

        def unzip(self, data, compression):
            """Decompress data using a zip format."""
            if compression == Entry.COMP_ZIP:
                return zlib.decompress(data)
            elif compression == Entry.COMP_GZIP:
                return gzip.decompress(data)
            elif compression == Entry.COMP_BZIP2:
                return bz2.decompress(data)
            else:
                raise Util.exception(
                    Error.AR7_INVALID_COMPRESSION, {"compression": compression}
                )

        def vacuum(self):
            """Clean up empty space and align data."""
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
            while hidx:
                entry = entries.get_entry(hidx)
                data = self.load_data(entry)
                self.write_data(offset, data + self.filler(data))

                entry = entry._asdict()
                entry["offset"] = offset
                entry = Entry(**entry)
                entries.update(entry, hidx)

                offset = entries._sector(offset + entry.size)
                hidx = entries.get_hithermost(offset)

            self.ioc.fileobj.truncate(offset)

    class Query:
        """Low level query API."""

        EQ = "="  # b'e'
        NE = "≠"  # b'n'
        GT = ">"  # b'g'
        LT = "<"  # b'l'

        def __init__(self, pattern="*"):
            """Init a query."""
            self.__type = (Entry.TYPE_FILE, Entry.TYPE_DIR, Entry.TYPE_LINK)
            self.__file_regex = None
            self.__dir_regex = None
            if not pattern == "*":
                filename = (
                    re.escape(os.path.basename(pattern))
                    .replace("\*", ".*")
                    .replace("\?", ".")
                )
                dirname = (
                    re.escape(os.path.dirname(pattern))
                    .replace("\*", ".*")
                    .replace("\?", ".")
                )
                if filename:
                    self.__file_regex = re.compile(bytes(filename, "utf-8"))
                if dirname:
                    self.__dir_regex = re.compile(dirname)
            self.__id = None
            self.__parent = None
            self.__owner = None
            self.__created = None
            self.__modified = None
            self.__deleted = False
            self.__user = None
            self.__group = None

        @property
        def types(self):
            """File system entry types."""
            return self.__type

        def type(self, _type=None, operand="="):
            """Search for an entry type."""
            Util.is_type(_type, (tuple, bytes, type(None)))
            if isinstance(_type, tuple):
                self.__type = _type
            elif isinstance(_type, bytes):
                self.__type = (_type,)
            return self

        def id(self, id=None):
            """Search for ID."""
            Util.is_type(id, uuid.UUID)
            self.__id = id
            return self

        def parent(self, parent, operand="="):
            """Search with directory ID."""
            Util.is_type(parent, (uuid.UUID, tuple, type(None)))
            if operand not in ["=", "≠"]:
                raise Util.exception(
                    Error.AR7_OPERAND_INVALID, {"operand": operand}
                )
            if isinstance(parent, uuid.UUID):
                self.__parent = ([parent.int], operand)
            elif isinstance(parent, tuple):
                ints = []
                for i in parent:
                    ints.append(i.int)
                self.__parent = (ints, operand)
            return self

        def owner(self, owner, operand="="):
            """Search with owner."""
            Util.is_type(owner, (uuid.UUID, tuple, type(None)))
            if operand not in ["=", "≠"]:
                raise Util.exception(
                    Error.AR7_OPERAND_INVALID, {"operand": operand}
                )
            if isinstance(owner, uuid.UUID):
                self.__owner = ([owner.int], operand)
            elif isinstance(owner, tuple):
                ints = []
                for i in owner:
                    ints.append(i.int)
                self.__owner = (ints, operand)
            return self

        def created(self, created, operand="<"):
            """Search with creation date."""
            Util.is_type(created, (int, str, datetime.datetime))
            if operand not in ["=", ">", "<"]:
                raise Util.exception(
                    Error.AR7_OPERAND_INVALID, {"operand": operand}
                )
            if isinstance(created, int):
                created = datetime.datetime.fromtimestamp(created)
            elif isinstance(created, str):
                created = datetime.datetime.fromisoformat(created)
            self.__created = (created, operand)
            return self

        def modified(self, modified, operand="<"):
            """Search with modified date."""
            Util.is_type(modified, (int, str, datetime.datetime))
            if operand not in ["=", ">", "<"]:
                raise Util.exception(
                    Error.AR7_OPERAND_INVALID, {"operand": operand}
                )
            if isinstance(modified, int):
                modified = datetime.datetime.fromtimestamp(modified)
            elif isinstance(modified, str):
                modified = datetime.datetime.fromisoformat(modified)
            self.__modified = (modified, operand)
            return self

        def deleted(self, deleted):
            """Search for deleted."""
            Util.is_type(deleted, (bool, type(None)))
            self.__deleted = deleted
            return self

        def user(self, user, operand="="):
            """Search with unix username."""
            Util.is_type(user, (str, tuple, type(None)))
            if operand not in ["=", "≠"]:
                raise Util.exception(
                    Error.AR7_OPERAND_INVALID, {"operand": operand}
                )
            if isinstance(user, str):
                self.__user = ([user.encode("utf-8")], operand)
            elif isinstance(user, tuple):
                ints = []
                for i in user:
                    ints.append(i.encode("utf-8"))
                self.__user = (ints, operand)
            return self

        def group(self, group, operand="="):
            """Search with unix group."""
            Util.is_type(group, (str, tuple, type(None)))
            if operand not in ["=", "≠"]:
                raise Util.exception(
                    Error.AR7_OPERAND_INVALID, {"operand": operand}
                )
            if isinstance(group, str):
                self.__group = ([group.encode("utf-8")], operand)
            elif isinstance(group, tuple):
                ints = []
                for i in group:
                    ints.append(i.encode("utf-8"))
                self.__group = (ints, group)
            return self

        def build(self, paths=None):
            """Generate the search query function."""
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

            def _deleted_any(x):
                return True

            def _user_is(x):
                return x.user in self.__user[0]

            def _user_not(x):
                return x.user not in self.__user[0]

            def _group_is(x):
                return x.group in self.__group[0]

            def _group_not(x):
                return x.group not in self.__group[0]

            qualifiers = [_type_in]

            if self.__file_regex:
                qualifiers.append(_name_match)
            if self.__id:
                qualifiers.append(_id_is)
            if self.__parent:
                if self.__parent[1] == "=":
                    qualifiers.append(_parent_is)
                elif self.__parent[1] == "≠":
                    qualifiers.append(_parent_not)
            if self.__owner:
                if self.__owner[1] == "=":
                    qualifiers.append(_owner_is)
                elif self.__owner[1] == "≠":
                    qualifiers.append(_owner_not)
            if self.__created:
                if self.__created[1] == "=":
                    qualifiers.append(_created_eq)
                elif self.__created[1] == "<":
                    qualifiers.append(_created_lt)
                elif self.__created[1] == ">":
                    qualifiers.append(_created_gt)
            if self.__modified:
                if self.__modified[1] == "=":
                    qualifiers.append(_modified_eq)
                elif self.__modified[1] == "<":
                    qualifiers.append(_modified_lt)
                elif self.__modified[1] == ">":
                    qualifiers.append(_modified_gt)
            if isinstance(self.__deleted, bool):
                if self.__deleted:
                    qualifiers.append(_deleted_is)
                else:
                    qualifiers.append(_deleted_not)
            elif isinstance(self.__deleted, type(None)):
                qualifiers.append(_deleted_any)
            if self.__user:
                if self.__user[1] == "=":
                    qualifiers.append(_user_is)
                elif self.__user[1] == "≠":
                    qualifiers.append(_user_not)
            if self.__group:
                if self.__group[1] == "=":
                    qualifiers.append(_group_is)
                elif self.__group[1] == "≠":
                    qualifiers.append(_group_not)

            def query(x):
                for q in qualifiers:
                    if not q(x[1]):
                        return False
                return True

            return query

    class Delete(enum.IntEnum):
        """Delete mode flags."""

        SOFT = 1  # Raise file delete flag
        HARD = (
            2
        )  # Raise  file delete flag, set size and offset to zero, add empty block.  # noqa #E501
        ERASE = 3  # Replace file with empty block

    def __del__(self):
        """Destructor."""
        self.close()
