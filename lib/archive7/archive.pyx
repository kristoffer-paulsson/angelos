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
        pass

    @property
    def closed(self):
        pass

    def close(self):
        pass

    def open(self, path: str, mode: str = "r") -> VirtualFileObject:
        pass

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
