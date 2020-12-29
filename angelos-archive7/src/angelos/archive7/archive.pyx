# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Archive implementation."""
import datetime
import functools
import os
import re
import struct
import time
import uuid
from pathlib import Path, PurePosixPath
from typing import Union

from angelos.archive7.fs import Delete, InvalidPath, EntryRecord, FileObject
from angelos.archive7.fs import FileSystemStreamManager, TYPE_DIR, TYPE_LINK, TYPE_FILE, \
    HierarchyTraverser
from angelos.common.misc import SharedResourceMixin
from angelos.common.utils import Util


class Archive7Error(RuntimeError):
    """Errors related to Archive7."""
    INVALID_FORMAT = ("Invalid format", 120)
    AR7_NOT_FOUND = ("Archive file not found", 121)
    AR7_OPERAND_INVALID = ("Invalid or unsupported operand", 122)


class Header:
    """Header for the Archive 7 format."""

    __slots__ = ["major", "minor", "type", "role", "use", "id", "owner", "domain", "node", "created", "title"]

    FORMAT = "!8scHHbbb16s16s16s16sQ256s"

    def __init__(
            self, owner: uuid.UUID, identity: uuid.UUID = None, node: uuid.UUID = None, domain: uuid.UUID = None,
            title: Union[bytes, bytearray] = None, type_: int = None, role: int = None, use: int = None,
            major: int = 2, minor: int = 0, created: datetime.datetime = None
    ):
        self.major = major
        self.minor = minor
        self.type = type_
        self.role = role
        self.use = use
        self.id = identity
        self.owner = owner
        self.domain = domain
        self.node = node
        self.created = created if created else datetime.datetime.now()
        self.title = title

    def __bytes__(self):
        return struct.pack(
            Header.FORMAT,
            b"archive7",
            b"a",
            2,
            0,
            self.type if self.type else 0,
            self.role if self.role else 0,
            self.use if self.use else 0,
            self.id.bytes if isinstance(self.id, uuid.UUID) else uuid.uuid4().bytes,
            self.owner.bytes if isinstance(self.owner, uuid.UUID) else bytes(16),
            self.domain.bytes if isinstance(self.domain, uuid.UUID) else bytes(16),
            self.node.bytes if isinstance(self.node, uuid.UUID) else bytes(16),
            int(
                time.mktime(self.created.timetuple())
                if isinstance(self.created, datetime.datetime)
                else time.mktime(datetime.datetime.now().timetuple())
            ),
            self.title[:256] if isinstance(self.title, (bytes, bytearray)) else bytes(256)
        )

    @staticmethod
    def meta_unpack(data: Union[bytes, bytearray]) -> "Header":
        metadata = struct.unpack(Header.FORMAT, data)

        if metadata[0] != b"archive7" or metadata[1] != b"a":
            raise Archive7Error(*Archive7Error.INVALID_FORMAT)

        return Header(
            type_=metadata[4],
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


class Archive7(SharedResourceMixin):
    """Archive main class and high level API."""

    def __init__(self, filename: Path, secret: bytes, delete: int = Delete.ERASE):
        """Init archive using a file object and set delete mode."""
        SharedResourceMixin.__init__(self)
        self.__closed = False
        self.__delete = delete
        self.__manager = FileSystemStreamManager(filename, secret)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()

    @staticmethod
    def setup(filename: Path, secret: bytes, owner: uuid.UUID = None, node: uuid.UUID = None, title: str = None,
              domain: uuid.UUID = None, type_: int = None, role: int = None, use: int = None):
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
            type_ (int):
                Facade type
            role (int):
                Node role
            use (int):
                Archive usage

        Returns (Archive7):
            Initialized Archive7 instance

        """
        header = Header(
            owner=owner, node=node, title=title.encode() if title else title,
            domain=domain, type_=type_, role=role, use=use
        )

        archive = Archive7(filename, secret)
        archive._Archive7__manager.meta = bytes(header)
        archive._Archive7__manager.save_meta()
        return archive

    @staticmethod
    def open(filename: Path, secret: bytes, delete: int = 3):
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
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename})

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
        size = struct.calcsize(Header.FORMAT)
        return Header.meta_unpack(self.__manager.meta[:size])

    async def info(self, *args, **kwargs):
        return await self._run(functools.partial(self.__info, *args, **kwargs))

    def __info(self, filename: PurePosixPath) -> EntryRecord:
        """Information about a file.

        Args:
            filename (str):
                Path and name of file

        Returns (ArchiveEntry):
            File entry from registry

        """
        try:
            return self.__manager.search_entry(self.__manager.resolve_path(filename))
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename})

    async def glob(
            self,
            name: str = "*",
            id: uuid.UUID = None,
            parent: uuid.UUID = None,
            owner: uuid.UUID = None,
            created: datetime.datetime = None,
            modified: datetime.datetime = None,
            deleted: bool = False,
            user: str = None,
            group: str = None
    ) -> set:
        """Glob the file system in the archive."""
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

        files = set()
        async for entry, path in self.search(sq):
            files.add(path)

        return files

    async def move(self, *args, **kwargs):
        return await self._run(functools.partial(self.__move, *args, **kwargs))

    def __move(self, filename: PurePosixPath, dirname: PurePosixPath):
        """Move file/dir to another directory."""
        try:
            identity = self.__manager.resolve_path(filename)
            parent = self.__manager.resolve_path(dirname)
            self.__manager.change_parent(identity, parent)
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"filename": filename, "dirname": dirname})

    async def chmod(self, *args, **kwargs):
        return await self._run(functools.partial(self.__chmod, *args, **kwargs))

    def __chmod(
            self,
            filename: PurePosixPath,
            # id: uuid.UUID = None,
            owner: uuid.UUID = None,
            deleted: bool = None,
            user: str = None,
            group: str = None,
            perms: int = None,
    ):
        """Update ID/owner or deleted status for an entry."""
        try:
            self.__manager.update_entry(
                self.__manager.resolve_path(filename),
                owner=owner, deleted=deleted, user=user, group=group, perms=perms
            )
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename})

    async def remove(self, *args, **kwargs):
        return await self._run(functools.partial(self.__remove, *args, **kwargs))

    def __remove(self, filename: PurePosixPath, mode: int = None):
        """Remove file or dir."""
        try:
            self.__manager.delete_entry(
                self.__manager.resolve_path(filename), mode if mode else self.__delete)
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename})

    async def rename(self, *args, **kwargs):
        return await self._run(functools.partial(self.__rename, *args, **kwargs))

    def __rename(self, filename: PurePosixPath, dest: str):
        """Rename file or directory."""
        try:
            self.__manager.change_name(self.__manager.resolve_path(filename), dest)
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename})

    async def isdir(self, *args, **kwargs):
        return await self._run(functools.partial(self.__isdir, *args, **kwargs))

    def __isdir(self, dirname: PurePosixPath) -> bool:
        """Check if a path is a known directory."""
        try:
            return self.__manager.search_entry(self.__manager.resolve_path(dirname, True)).type == TYPE_DIR
        except InvalidPath:
            return False

    async def isfile(self, *args, **kwargs):
        return await self._run(functools.partial(self.__isfile, *args, **kwargs))

    def __isfile(self, filename: PurePosixPath) -> bool:
        """Check if a path is a known file."""
        try:
            return self.__manager.search_entry(self.__manager.resolve_path(filename, True)).type == TYPE_FILE
        except InvalidPath:
            return False

    async def islink(self, *args, **kwargs):
        return await self._run(functools.partial(self.__islink, *args, **kwargs))

    def __islink(self, filename: PurePosixPath) -> bool:
        """Check if a path is a known link."""
        try:
            return self.__manager.search_entry(self.__manager.resolve_path(filename, False)).type == TYPE_LINK
        except InvalidPath:
            return False

    async def mkdir(self, *args, **kwargs):
        return await self._run(functools.partial(self.__mkdir, *args, **kwargs))

    def __mkdir(
            self,
            dirname: PurePosixPath,
            user: str = None,
            group: str = None,
            perms: int = None
    ) -> uuid.UUID:
        """
        Make a new directory and super directories if missing.

            name        The full path and name of new directory
            returns     the entry ID
        """
        try:
            return self.__manager.create_entry(
                TYPE_DIR, dirname.parts[-1],
                self.__manager.resolve_path(dirname.parent),
                user=user, group=group, perms=perms
            )
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": dirname.parent})


    async def mkfile(self, *args, **kwargs):
        return await self._run(functools.partial(self.__mkfile, *args, **kwargs))

    def __mkfile(
            self,
            filename: PurePosixPath,
            data: bytes,
            created: datetime.datetime = None,
            modified: datetime.datetime = None,
            owner: uuid.UUID = None,
            parent: uuid.UUID = None,
            id: uuid.UUID = None,
            user: str = None,
            group: str = None,
            perms: int = None
    ) -> uuid.UUID:
        """Create a new file."""
        try:
            parent = self.__manager.resolve_path(filename.parent)
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"parent": filename.parent})

        identity = self.__manager.create_entry(
            type_=TYPE_FILE,
            name=filename.parts[-1],
            stream=uuid.UUID(int=0),
            parent=parent,
            identity=id,
            owner=owner,
            created=created,
            modified=modified,
            user=user,
            group=group,
            perms=perms,
        )

        vfd = self.__manager.open(identity, "wb")
        vfd.write(data)
        length = vfd.stream.length()
        vfd.close()
        self.__manager.update_entry(identity, length=length)
        return identity

    async def link(self, *args, **kwargs):
        return await self._run(functools.partial(self.__link, *args, **kwargs))

    def __link(
            self,
            filename: PurePosixPath,
            target: PurePosixPath,
            created: datetime.datetime = None,
            modified: datetime.datetime = None,
            user: str = None,
            group: str = None,
            perms: int = None
    ) -> uuid.UUID:
        """Create a new link to file or directory."""
        try:
            parent = self.__manager.resolve_path(filename.parent)
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename.parent})

        try:
            owner = self.__manager.resolve_path(target)
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"target": target})

        return self.__manager.create_entry(
            type_=TYPE_LINK,
            name=filename.parts[-1],
            parent=parent,
            owner=owner,
            created=created,
            modified=modified,
            user=user,
            group=group,
            perms=perms,
        )

    async def save(self, *args, **kwargs) -> uuid.UUID:
        return await self._run(functools.partial(self.__save, *args, **kwargs))

    def __save(self, filename: PurePosixPath, data: bytes, modified: datetime.datetime = None):
        """Update a file with new data."""
        if not modified:
            modified = datetime.datetime.now()

        try:
            identity = self.__manager.resolve_path(filename, True)
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename})

        vfd = self.__manager.open(identity, "wb")
        vfd.write(data)
        vfd.truncate()
        length = vfd.stream.length()
        vfd.close()
        self.__manager.update_entry(identity, modified=modified, length=length)
        return identity

    async def load(self, *args, **kwargs):
        return await self._run(functools.partial(self.__load, *args, **kwargs))

    def __load(self, filename: PurePosixPath, fd: bool = False) -> Union[bytes, FileObject]:
        """Load data from a file."""
        try:
            if fd:
                return self.__manager.open(self.__manager.resolve_path(filename, True), "rb")
            else:
                vfd = self.__manager.open(self.__manager.resolve_path(filename, True), "rb")
                data = vfd.read()
                vfd.close()
                return data
        except InvalidPath:
            raise Archive7Error(*Archive7Error.AR7_NOT_FOUND, {"path": filename})

    async def search(self, query: "Archive7.Query"):
        """Search is an async generator that iterates over the file system hierarchy.

        Use accordingly:
        query = Archive.Query()
        async for entry, path in archive.search(query):
            pass
        """
        evaluator = query.build()
        traverser = self.__manager.traverse_hierarchy(uuid.UUID(int=0))

        while True:
            entry, path = await self._wild(functools.partial(self.__search, traverser=traverser))
            if not entry:
                break
            if evaluator(entry, str(path)):
                yield entry, path

    def __search(self, traverser: HierarchyTraverser) -> tuple:
        """Load data from a file."""
        try:
            return next(traverser)
        except StopIteration:
            return None, None

    class Query:
        """Low level query API."""

        EQ = "="  # b'e'
        NE = "≠"  # b'n'
        GT = ">"  # b'g'
        LT = "<"  # b'l'

        def __init__(self, pattern: str ="*"):
            """Init a query."""
            self.__type = (TYPE_FILE, TYPE_DIR, TYPE_LINK)
            self.__path_regex = None
            if not pattern == "*":
                path = re.escape(pattern).replace("\*", ".*").replace("\?", ".")
                self.__path_regex = re.compile(path)
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

        def id(self, identity=None):
            """Search for ID."""
            Util.is_type(identity, uuid.UUID)
            self.__id = identity
            return self

        def parent(self, parent, operand="="):
            """Search with directory ID."""
            Util.is_type(parent, (uuid.UUID, tuple, type(None)))
            if operand not in ["=", "≠"]:
                raise Archive7Error(*Archive7Error.AR7_OPERAND_INVALID, {"operand": operand})
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
                raise Archive7Error(*Archive7Error.AR7_OPERAND_INVALID, {"operand": operand})
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
                raise Archive7Error(*Archive7Error.AR7_OPERAND_INVALID, {"operand": operand})
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
                raise Archive7Error(*Archive7Error.AR7_OPERAND_INVALID, {"operand": operand})
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
                raise Archive7Error(*Archive7Error.AR7_OPERAND_INVALID, {"operand": operand})
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
                raise Archive7Error(*Archive7Error.AR7_OPERAND_INVALID, {"operand": operand})
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

            def _type_in(x):
                return x.type in self.__type

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

            def query(rec, path):
                """Evaluate entry and path against criteria."""
                if self.__path_regex:
                    if not bool(self.__path_regex.match(path)):
                        return False

                for q in qualifiers:
                    if not q(rec):
                        return False
                return True

            return query
