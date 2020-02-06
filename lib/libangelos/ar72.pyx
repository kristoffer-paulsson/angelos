# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Archive7 NG

Next generation of Archive7 containing three layers.

a) transparent encryption layer
b) on-disk nested linked lists
c) BTree indexed file system

In future C implementation, use BTree for entries:
https://github.com/antirez/otree
"""
import io


class AbstractFileObject(io.RawIOBase):
    """FileIO-compliant and transparent abstract file object layer."""

    def __init__(self, path, mode):
        self.__name = path
        self.__mode = mode
        self.__readable = False
        self.__writable = False
        self.__seekable = False
        self.__closed = False

    def __is_closed(self):
        if self.closed:
            raise ValueError()

    def __is_readable(self):
        if not self.__readable:
            raise OSError()

    def __is_writable(self):
        if not self.__writable:
            raise OSError()

    def __is_seekable(self):
        if not self.__seekable:
            raise OSError()

    @property
    def name(self):
        """Name of the file a string."""
        return self.__name

    @property
    def mode(self):
        """File mode as string."""
        return self.__mode

    @property
    def closed(self):
        """Mode property."""
        return self.__closed

    def close(self):
        """
        Flush and close the IO object.

        This method has no effect if the file is already closed.
        """
        if not self.closed:
            super().close(self)
            self.__closed = True


    def fileno(self):
        """
        Return underlying file descriptor (an int) if one exists.

        An OSError is raised if the IO object does not use a file descriptor.
        """
        raise OSError()

    def flush(self):
        """
        Flush write buffers, if applicable.

        This is not implemented for read-only and non-blocking streams.
        """
        super().flush(self)

    def isatty(self):
        """Return true if the file is connected to a TTY device."""
        self.__is_closed()
        return False

    def readinto(self, b):
        """
        Read bytes into a pre-allocated bytes-like object b.

        Returns an int representing the number of bytes read (0 for EOF), or
        None if the object is set not to block and has no data to read.
        """
        self.__is_closed()
        self.__is_readable()

    def readable(self):
        """Return true if file was opened in a read mode."""
        self.__is_closed()
        return self.__readable

    def seek(self, offset, whence=io.SEEK_SET):
        """
        Change stream position.

        Change the stream position to byte offset pos. Argument pos is
        interpreted relative to the position indicated by whence.  Values
        for whence are ints:
        * 0 -- start of stream (the default); offset should be zero or positive
        * 1 -- current stream position; offset may be negative
        * 2 -- end of stream; offset is usually negative
        Some operating systems / file systems could provide additional values.
        Return an int indicating the new absolute position.
        """
        self.__is_closed()
        self.__is_seekable()

        return self.__position

    def seekable(self):
        """Return true if file supports random-access."""
        self.__is_closed()
        return self.__seekable

    def tell(self):
        """Tell current IO position."""
        self.__is_seekable()

        return self.__position

    def truncate(self, size=None):
        """
        Truncate file to size bytes.

        Size defaults to the current IO position as reported by tell(). Return
        the new size.
        """
        self.__is_closed()
        self.__is_writable()
        self.__is_seekable()

    def writable(self):
        """If file is writable, returns True, else False."""
        self.__is_closed()
        return self.__writable

    def write(self, b):
        """
        Write the given buffer to the IO stream.

        Returns the number of bytes written, which may be less than the
        length of b in bytes.
        """
        self.__is_closed()
        self.__is_writable()


class FilesystemMixin:
    """Mixin for all essential function calls for a file system."""

    def access(self, path, mode, *, dir_fd=None, effective_ids=False, follow_symlinks=True):
        raise NotImplementedError()

    def chflags(self, path, flags, *, follow_symlinks=True):
        raise NotImplementedError()

    def chmod(self, path, mode, *, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def chown(self, path, uid, gid, *, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def lchflags(self, path, flags):
        raise NotImplementedError()

    def lchmod(self, path, mode):
        raise NotImplementedError()

    def lchown(self, path, uid, gid):
        raise NotImplementedError()

    def link(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def listdir(self, path="."):
        raise NotImplementedError()

    def lstat(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def mkdir(self, path, mode=0o777, *, dir_fd=None):
        raise NotImplementedError()

    def makedirs(self, name, mode=0o777, exist_ok=False):
        raise NotImplementedError()

    def mkfifo(self, path, mode=0o666, *, dir_fd=None):
        raise NotImplementedError()

    def readlink(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def remove(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def removedirs(self, name):
        raise NotImplementedError()

    def rename(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None):
        raise NotImplementedError()

    def renames(self, old, new):
        raise NotImplementedError()

    def replace(self, src, dst, *, src_dir_fd=None, dst_dir_fd=None):
        raise NotImplementedError()

    def rmdir(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def scandir(self, path="."):
        raise NotImplementedError()

    def stat(self, path, *, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def symlink(self, src, dst, target_is_directory=False, *, dir_fd=None):
        raise NotImplementedError()

    def sync(self):
        raise NotImplementedError()

    def truncate(self, path, length):
        raise NotImplementedError()

    def unlink(self, path, *, dir_fd=None):
        raise NotImplementedError()

    def time(self, path, times=None, *, ns, dir_fd=None, follow_symlinks=True):
        raise NotImplementedError()

    def walk(self, top, topdown=True, onerror=None, followlinks=False):
        raise NotImplementedError()

    def fwalk(self, top=".", topdown=True, onerror=None, *, follow_symlinks=False, dir_fd=None):
        raise NotImplementedError()


class AbstractVirtualFilesystem(FilesystemMixin):
    """Abstract class for a virtual file system."""

    def __init__(self):
        pass

    def unmount(self):
        pass


class AbstractFilesystemSession(FilesystemMixin):
    """Abstract class for a file system session. (current directory support)."""
    def __init__(self):
        pass

    def chdir(self, path):
        pass

    def chroot(self, path):
        pass

    def fchdir(self, fd):
        pass

    def getcwd(self):
        pass

    def getcwdb(self):
        pass