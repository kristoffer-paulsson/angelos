# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""File system."""
from abc import ABC, abstractmethod


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