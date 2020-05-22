# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Archive implementation."""
import copy
import datetime
import enum
import functools
import os
import re
import struct
import time
import uuid
from typing import Union

from archive7.fs import FileSystemStreamManager
from libangelos.misc import SharedResource
from libangelos.utils import Util

from error import Error


class Header:
    """Header for the Archive 7 format."""

    __slots__ = ["major", "minor", "type", "role", "use", "id", "owner", "domain", "node", "created", "title"]

    FORMAT = "!8scHHbbb16s16s16s16sQ256s"

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
            Header.FORMAT,
            b"archive7",
            b"a",
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
        metadata = struct.unpack(Header.FORMAT, data)

        if metadata[0] != b"archive7" or metadata[1] != b"a":
            raise RuntimeError("Invalid format")

        return Header(
            type=metadata[4],
            role=metadata[5],
            use=metadata[6],
            identity=uuid.UUID(bytes=metadata[7]),
            owner=uuid.UUID(bytes=metadata[8]),
            domain=uuid.UUID(bytes=metadata[9]),
            node=uuid.UUID(bytes=metadata[10]),
            created=datetime.datetime.fromtimestamp(metadata[11]),
            title=metadata[12].strip(b"\x00"),
            major=metadata[2],
            minor=metadata[3],
        )


class Archive7(SharedResource):
    """Archive main class and high level API."""

    def __init__(self, filename: str, secret: bytes, delete: int = 3):
        """Init archive using a file object and set delete mode."""
        SharedResource.__init__(self)
        self.__closed = False
        self.__delete = delete if delete else Archive7.Delete.ERASE
        self.__manager = FileSystemStreamManager(filename, secret)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    @staticmethod
    def setup(filename: str, secret: bytes, owner: uuid.UUID = None, node: uuid.UUID = None, title: str = None,
              domain: uuid.UUID = None, type: int = None, role: int = None, use: int = None):
        """Create a new archive.

        Args:
            filename (str):
                Path and filename to archive
            secret (bytes):
                Encryption key
            owner (uuid.UUID):
                Angelos owner UUID
            node (uuid.UUID):
                Angelos node UUID
            title (str):
                Title or name of the archive
            domain (uuid.UUID):
                Angelos domain UUID
            type (int):
                Facade type
            role (int):
                Node role
            use (int):
                Archive usage

        Returns (Archive7):
            Initialized Archive7 instance

        """
        header = Header(
            owner=owner, node=node, title=title.encode(),
            domain=domain, type=type, role=role, use=use
        )

        archive = Archive7(filename, secret)
        archive.meta = bytes(header)
        return archive

    @staticmethod
    def open(filename: str, secret: bytes, delete=3):
        """Open an archive with a symmetric encryption key.

        Args:
            filename (str):
                Path and filename to archive
            secret (bytes):
                Encryption key
            delete (int):
                Delete methodology

        Returns (Archive7):
            Opened Archive7 instance

        """
        if not os.path.isfile(filename):
            raise Util.exception(Error.AR7_NOT_FOUND, {"path": filename})

        return Archive7(filename, secret, delete)

    @property
    def closed(self):
        """Archive closed status."""
        return self.__closed

    def close(self):
        """Close archive."""
        if not self.__closed:
            self.__manager.close()
            self.__closed = True

    def stats(self):
        """Archive stats."""
        return Header.meta_unpack(self.__manager.meta)

    async def info(self, *args, **kwargs):
        return await self._run(functools.partial(self.__info, *args, **kwargs))

    def __info(self, filename: str):
        """Information about a file.

        Args:
            filename (str):
                Path and name of file

        Returns (ArchiveEntry):
            File entry from registry

        """

        dirname, name = os.path.split(filename)
        pid = ops.get_pid(dirname)
        entry, idx = ops.find_entry(name, pid)

        return copy.deepcopy(entry)

    async def glob(self, *args, **kwargs):
        return await self._run(functools.partial(self.__glob, *args, **kwargs))

    def __glob(
            self,
            name="*",
            id=None,
            parent=None,
            owner=None,
            created=None,
            modified=None,
            deleted=False,
            user=None,
            group=None
    ):
        """Glob the file system in the archive."""
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

        files = set()
        for i in idxs:
            idx, entry = i
            filename = entry.name.decode()
            if entry.parent.int == 0:
                name = "/" + filename
            else:
                name = ids[entry.parent] + "/" + filename
            files.add(name)

        return files

    async def move(self, *args, **kwargs):
        return await self._run(functools.partial(self.__move, *args, **kwargs))

    def __move(self, src, dest):
        """Move file/dir to another directory."""
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

    async def chmod(self, *args, **kwargs):
        return await self._run(functools.partial(self.__chmod, *args, **kwargs))

    def __chmod(
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

    async def remove(self, *args, **kwargs):
        return await self._run(functools.partial(self.__remove, *args, **kwargs))

    def __remove(self, filename, mode=None):
        """Remove file or dir."""
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

    async def rename(self, *args, **kwargs):
        return await self._run(functools.partial(self.__rename, *args, **kwargs))

    def __rename(self, path, dest):
        """Rename file or directory."""
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

    def __is_type(self, filename, etype):
        try:
            ops = self.ioc.operations

            dirname, name = os.path.split(filename)
            pid = ops.get_pid(dirname)
            entry, idx = ops.find_entry(name, pid)
            return True if entry.type == etype else False
        except (ArchiveInvalidFile,):
            return False

    def isfile(self, filename):
        """Check if a path is a known file."""
        return self.__is_type(filename, Entry.TYPE_FILE)

    def islink(self, filename):
        """Check if a path is a known file."""
        return self.__is_type(filename, Entry.TYPE_LINK)

    async def mkdir(self, *args, **kwargs):
        return await self._run(functools.partial(self.__mkdir, *args, **kwargs))

    def __mkdir(self, dirname, user=None, group=None, perms=None):
        """
        Make a new directory and super directories if missing.

            name        The full path and name of new directory
            returns     the entry ID
        """
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

    async def mkfile(self, *args, **kwargs):
        return await self._run(functools.partial(self.__mkfile, *args, **kwargs))

    def __mkfile(
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
            perms=None
    ):
        """Create a new file."""
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

    async def link(self, *args, **kwargs):
        return await self._run(functools.partial(self.__link, *args, **kwargs))

    def __link(
            self,
            path,
            link,
            created=None,
            modified=None,
            user=None,
            group=None,
            perms=None
    ):
        """Create a new link to file or directory."""
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

    async def save(self, *args, **kwargs):
        return await self._run(functools.partial(self.__save, *args, **kwargs))

    def __save(self, filename, data, compression=Entry.COMP_NONE, modified=None):
        """Update a file with new data."""
        if not modified:
            modified = datetime.datetime.now()

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

    async def load(self, *args, **kwargs):
        return await self._run(functools.partial(self.__load, *args, **kwargs))

    def __load(self, filename):
        """Load data from a file."""
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

    def __del__(self):
        """Destructor."""
        self.close()
