# Copyright (c) 2015-2018 by Ron Frederick <ronf@timeheart.net> and others.
#
# This program and the accompanying materials are made available under
# the terms of the Eclipse Public License v2.0 which accompanies this
# distribution and is available at:
#
#     http://www.eclipse.org/legal/epl-2.0/
#
# This program may also be made available under the following secondary
# licenses when the conditions for such availability set forth in the
# Eclipse Public License v2.0 are satisfied:
#
#    GNU General Public License, Version 2.0, or any later versions of
#    that license
#
# SPDX-License-Identifier: EPL-2.0 OR GPL-2.0-or-later
#
# Contributors:
#     Ron Frederick - initial implementation, API, and documentation
#     Jonathan Slenders - proposed changes to allow SFTP server callbacks
#                         to be coroutines

"""SFTP handlers"""

import asyncio
from collections import OrderedDict
import errno
from fnmatch import fnmatch
import os
from os import SEEK_SET, SEEK_CUR, SEEK_END
from pathlib import PurePath
import posixpath
import stat
import sys
import time

from .constants import DEFAULT_LANG

from .constants import FXP_INIT, FXP_VERSION, FXP_OPEN, FXP_CLOSE, FXP_READ
from .constants import FXP_WRITE, FXP_LSTAT, FXP_FSTAT, FXP_SETSTAT
from .constants import FXP_FSETSTAT, FXP_OPENDIR, FXP_READDIR, FXP_REMOVE
from .constants import FXP_MKDIR, FXP_RMDIR, FXP_REALPATH, FXP_STAT, FXP_RENAME
from .constants import FXP_READLINK, FXP_SYMLINK, FXP_STATUS, FXP_HANDLE
from .constants import FXP_DATA, FXP_NAME, FXP_ATTRS, FXP_EXTENDED
from .constants import FXP_EXTENDED_REPLY

from .constants import FXF_READ, FXF_WRITE, FXF_APPEND
from .constants import FXF_CREAT, FXF_TRUNC, FXF_EXCL

from .constants import FILEXFER_ATTR_SIZE, FILEXFER_ATTR_UIDGID
from .constants import FILEXFER_ATTR_PERMISSIONS, FILEXFER_ATTR_ACMODTIME
from .constants import FILEXFER_ATTR_EXTENDED, FILEXFER_ATTR_UNDEFINED

from .constants import FX_OK, FX_EOF, FX_NO_SUCH_FILE, FX_PERMISSION_DENIED
from .constants import FX_FAILURE, FX_BAD_MESSAGE, FX_NO_CONNECTION
from .constants import FX_CONNECTION_LOST, FX_OP_UNSUPPORTED

from .misc import Error, Record, async_context_manager, get_symbol_names
from .misc import hide_empty, plural, to_hex

from .packet import Byte, String, UInt32, UInt64, PacketDecodeError
from .packet import SSHPacket, SSHPacketLogger

SFTP_BLOCK_SIZE = 16384

_SFTP_VERSION = 3
_MAX_SFTP_REQUESTS = 128
_MAX_READDIR_NAMES = 128

_open_modes = {
    'r':  FXF_READ,
    'w':  FXF_WRITE | FXF_CREAT | FXF_TRUNC,
    'a':  FXF_WRITE | FXF_CREAT | FXF_APPEND,
    'x':  FXF_WRITE | FXF_CREAT | FXF_EXCL,

    'r+': FXF_READ | FXF_WRITE,
    'w+': FXF_READ | FXF_WRITE | FXF_CREAT | FXF_TRUNC,
    'a+': FXF_READ | FXF_WRITE | FXF_CREAT | FXF_APPEND,
    'x+': FXF_READ | FXF_WRITE | FXF_CREAT | FXF_EXCL
}


def _mode_to_pflags(mode):
    """Convert open mode to SFTP open flags"""

    if 'b' in mode:
        mode = mode.replace('b', '')
        binary = True
    else:
        binary = False

    pflags = _open_modes.get(mode)

    if not pflags:
        raise ValueError('Invalid mode: %r' % mode)

    return pflags, binary


def _from_local_path(path):
    """Convert local path to SFTP path"""

    path = os.fsencode(path)

    if sys.platform == 'win32': # pragma: no cover
        path = path.replace(b'\\', b'/')

        if path[:1] != b'/' and path[1:2] == b':':
            path = b'/' + path

    return path


def _to_local_path(path):
    """Convert SFTP path to local path"""

    if isinstance(path, PurePath): # pragma: no branch
        path = str(path)

    if sys.platform == 'win32': # pragma: no cover
        path = os.fsdecode(path)

        if path[:1] == '/' and path[2:3] == ':':
            path = path[1:]

        path = path.replace('/', '\\')

    return path


def _setstat(path, attrs):
    """Utility function to set file attributes"""

    if attrs.size is not None:
        os.truncate(path, attrs.size)

    if attrs.uid is not None and attrs.gid is not None:
        try:
            os.chown(path, attrs.uid, attrs.gid)
        except AttributeError: # pragma: no cover
            raise NotImplementedError

    if attrs.permissions is not None:
        os.chmod(path, stat.S_IMODE(attrs.permissions))

    if attrs.atime is not None and attrs.mtime is not None:
        os.utime(path, times=(attrs.atime, attrs.mtime))


def _split_path_by_globs(pattern):
    """Split path grouping parts without glob pattern"""

    basedir, patlist, plain = None, [], []

    for current in pattern.split(b'/'):
        if any(c in current for c in b'*?[]'):
            if plain:
                if patlist:
                    patlist.append(plain)
                else:
                    basedir = b'/'.join(plain) or b'/'

                plain = []

            patlist.append(current)
        else:
            plain.append(current)

    if plain:
        patlist.append(plain)

    return basedir, patlist


@asyncio.coroutine
def _glob(fs, basedir, patlist, result):
    """Recursively match a glob pattern"""

    pattern, newpatlist = patlist[0], patlist[1:]

    names = yield from fs.listdir(basedir or b'.')

    if isinstance(pattern, list):
        if len(pattern) == 1 and not pattern[0] and not newpatlist:
            result.append(basedir)
            return

        for name in names:
            if name == pattern[0]:
                newbase = posixpath.join(basedir or b'', *pattern)
                yield from fs.stat(newbase)

                if not newpatlist:
                    result.append(newbase)
                else:
                    yield from _glob(fs, newbase, newpatlist, result)
                break
    else:
        if pattern == b'**':
            yield from _glob(fs, basedir, newpatlist, result)

        for name in names:
            if name in (b'.', b'..'):
                continue

            if fnmatch(name, pattern):
                newbase = posixpath.join(basedir or b'', name)

                if not newpatlist or (len(newpatlist) == 1 and
                                      not newpatlist[0]):
                    result.append(newbase)
                else:
                    attrs = yield from fs.stat(newbase)

                    if stat.S_ISDIR(attrs.permissions):
                        if pattern == b'**':
                            yield from _glob(fs, newbase, patlist, result)
                        else:
                            yield from _glob(fs, newbase, newpatlist, result)


@asyncio.coroutine
def match_glob(fs, pattern, error_handler=None):
    """Match a glob pattern"""

    names = []

    try:
        if any(c in pattern for c in b'*?[]'):
            basedir, patlist = _split_path_by_globs(pattern)
            yield from _glob(fs, basedir, patlist, names)

            if not names:
                raise SFTPError(FX_NO_SUCH_FILE, 'No matches found')
        else:
            yield from fs.stat(pattern)
            names.append(pattern)
    except (OSError, SFTPError) as exc:
        # pylint: disable=attribute-defined-outside-init
        exc.srcpath = pattern

        if error_handler:
            error_handler(exc)
        else:
            raise exc

    return names


class LocalFile:
    """A coroutine wrapper around local file I/O"""

    def __init__(self, f):
        self._file = f

    @classmethod
    def encode(cls, path):
        """Encode path name using filesystem native encoding

           This method has no effect if the path is already bytes.

        """

        if isinstance(path, PurePath): # pragma: no branch
            path = str(path)

        return os.fsencode(path)

    @classmethod
    def decode(cls, path):
        """Decode path name using filesystem native encoding

           This method has no effect if the path is already a string.

        """

        return os.fsdecode(path)

    @classmethod
    def compose_path(cls, path, parent=None):
        """Compose a path

           If parent is not specified, just encode the path.

        """

        return posixpath.join(parent, path) if parent else path

    @classmethod
    @asyncio.coroutine
    def open(cls, path, *args):
        """Open a local file"""

        return cls(open(_to_local_path(path), *args))

    @classmethod
    @asyncio.coroutine
    def stat(cls, path):
        """Get attributes of a local file or directory, following symlinks"""

        return SFTPAttrs.from_local(os.stat(_to_local_path(path)))

    @classmethod
    @asyncio.coroutine
    def lstat(cls, path):
        """Get attributes of a local file, directory, or symlink"""

        return SFTPAttrs.from_local(os.lstat(_to_local_path(path)))

    @classmethod
    @asyncio.coroutine
    def setstat(cls, path, attrs):
        """Set attributes of a local file or directory"""

        _setstat(_to_local_path(path), attrs)

    @classmethod
    @asyncio.coroutine
    def exists(cls, path):
        """Return if the local path exists and isn't a broken symbolic link"""

        return os.path.exists(_to_local_path(path))

    @classmethod
    @asyncio.coroutine
    def isdir(cls, path):
        """Return if the local path refers to a directory"""

        return os.path.isdir(_to_local_path(path))

    @classmethod
    @asyncio.coroutine
    def listdir(cls, path):
        """Read the names of the files in a local directory"""

        files = os.listdir(_to_local_path(path))

        if sys.platform == 'win32': # pragma: no cover
            files = [os.fsencode(f) for f in files]

        return files

    @classmethod
    @asyncio.coroutine
    def mkdir(cls, path):
        """Create a local directory with the specified attributes"""

        os.mkdir(_to_local_path(path))

    @classmethod
    @asyncio.coroutine
    def readlink(cls, path):
        """Return the target of a local symbolic link"""

        return _from_local_path(os.readlink(_to_local_path(path)))

    @classmethod
    @asyncio.coroutine
    def symlink(cls, oldpath, newpath):
        """Create a local symbolic link"""

        os.symlink(_to_local_path(oldpath), _to_local_path(newpath))

    @asyncio.coroutine
    def read(self, size, offset):
        """Read data from the local file"""

        self._file.seek(offset)
        return self._file.read(size)

    @asyncio.coroutine
    def write(self, data, offset):
        """Write data to the local file"""

        self._file.seek(offset)
        return self._file.write(data)

    @asyncio.coroutine
    def close(self):
        """Close the local file"""

        self._file.close()


class _SFTPParallelIO:
    """Parallelize I/O requests on files

       This class issues parallel read and wite requests on files.

    """

    def __init__(self, loop, block_size, max_requests, offset, size):
        self._loop = loop
        self._block_size = block_size
        self._max_requests = max_requests
        self._offset = offset
        self._bytes_left = size
        self._pending = set()

    def _start_tasks(self):
        """Create parallel file I/O tasks"""

        while self._bytes_left and len(self._pending) < self._max_requests:
            size = min(self._bytes_left, self._block_size)

            task = asyncio.Task(self.run_task(self._offset, size),
                                loop=self._loop)
            self._pending.add(task)

            self._offset += size
            self._bytes_left -= size

    @asyncio.coroutine
    def start(self):
        """Start parallel I/O"""

        pass

    @asyncio.coroutine
    def run_task(self, offset, size):
        """Perform file I/O on a particular byte range"""

        raise NotImplementedError

    @asyncio.coroutine
    def finish(self):
        """Finish parallel I/O"""

        pass

    @asyncio.coroutine
    def cleanup(self):
        """Clean up parallel I/O"""

        pass

    @asyncio.coroutine
    def run(self):
        """Perform all file I/O and return result or exception"""

        try:
            yield from self.start()

            self._start_tasks()

            while self._pending:
                done, self._pending = yield from asyncio.wait(
                    self._pending, return_when=asyncio.FIRST_COMPLETED)

                exceptions = []

                for task in done:
                    exc = task.exception()

                    if exc and exc.code != FX_EOF:
                        exceptions.append(exc)

                if exceptions:
                    for task in self._pending:
                        task.cancel()

                    raise exceptions[0]

                self._start_tasks()

            return (yield from self.finish())
        finally:
            yield from self.cleanup()


class _SFTPFileReader(_SFTPParallelIO):
    """Parallelized SFTP file reader"""

    def __init__(self, loop, block_size, max_requests,
                 handler, handle, offset, size):
        super().__init__(loop, block_size, max_requests, offset, size)

        self._handler = handler
        self._handle = handle
        self._start = offset
        self._data = bytearray()

    @asyncio.coroutine
    def run_task(self, offset, size):
        """Read a block of the file"""

        data = yield from self._handler.read(self._handle, offset, size)
        pos = offset - self._start
        pad = pos - len(self._data)

        if pad > 0:
            self._data += pad * b'\0'

        self._data[pos:pos+size] = data

    @asyncio.coroutine
    def finish(self):
        """Finish parallel read"""

        return bytes(self._data)


class _SFTPFileWriter(_SFTPParallelIO):
    """Parallelized SFTP file writer"""

    def __init__(self, loop, block_size, max_requests,
                 handler, handle, offset, data):
        super().__init__(loop, block_size, max_requests, offset, len(data))

        self._handler = handler
        self._handle = handle
        self._start = offset
        self._data = data

    @asyncio.coroutine
    def run_task(self, offset, size):
        """Write a block to the file"""

        pos = offset - self._start
        yield from self._handler.write(self._handle, offset,
                                       self._data[pos:pos+size])


class _SFTPFileCopier(_SFTPParallelIO):
    """SFTP file copier

       This class parforms an SFTP file copy, initiating multiple
       read and write requests to copy chunks of the file in parallel.

    """

    def __init__(self, loop, block_size, max_requests, offset, total_bytes,
                 srcfs, dstfs, srcpath, dstpath, progress_handler):
        super().__init__(loop, block_size, max_requests, offset, total_bytes)

        self._srcfs = srcfs
        self._dstfs = dstfs

        self._srcpath = srcpath
        self._dstpath = dstpath

        self._src = None
        self._dst = None

        self._bytes_copied = 0
        self._total_bytes = total_bytes
        self._progress_handler = progress_handler

    @asyncio.coroutine
    def start(self):
        """Start parallel copy"""

        self._src = yield from self._srcfs.open(self._srcpath, 'rb')
        self._dst = yield from self._dstfs.open(self._dstpath, 'wb')

    @asyncio.coroutine
    def run_task(self, offset, size):
        """Copy the next block of the file"""

        data = yield from self._src.read(size, offset)
        yield from self._dst.write(data, offset)

        if self._progress_handler:
            self._bytes_copied += size
            self._progress_handler(self._srcpath, self._dstpath,
                                   self._bytes_copied, self._total_bytes)

    @asyncio.coroutine
    def cleanup(self):
        """Clean up parallel copy"""

        if self._src: # pragma: no branch
            yield from self._src.close()

        if self._dst: # pragma: no branch
            yield from self._dst.close()


class SFTPError(Error):
    """SFTP error

       This exception is raised when an error occurs while processing
       an SFTP request. Exception codes should be taken from
       :ref:`SFTP error codes <SFTPErrorCodes>`.

       :param code:
           Disconnect reason, taken from :ref:`disconnect reason
           codes <DisconnectReasons>`
       :param reason:
           A human-readable reason for the disconnect
       :param lang:
           The language the reason is in
       :type code: `int`
       :type reason: `str`
       :type lang: `str`

    """


class SFTPAttrs(Record):
    """SFTP file attributes

       SFTPAttrs is a simple record class with the following fields:

         ============ =========================================== ======
         Field        Description                                 Type
         ============ =========================================== ======
         size         File size in bytes                          uint64
         uid          User id of file owner                       uint32
         gid          Group id of file owner                      uint32
         permissions  Bit mask of POSIX file permissions,         uint32
         atime        Last access time, UNIX epoch seconds        uint32
         mtime        Last modification time, UNIX epoch seconds  uint32
         ============ =========================================== ======

       In addition to the above, an `nlink` field is provided which
       stores the number of links to this file, but it is not encoded
       in the SFTP protocol. It's included here only so that it can be
       used to create the default `longname` string in :class:`SFTPName`
       objects.

       Extended attributes can also be added via a field named
       `extended` which is a list of string name/value pairs.

       When setting attributes using an :class:`SFTPAttrs`, only fields
       which have been initialized will be changed on the selected file.

    """

    # Unfortunately, pylint can't handle attributes defined with setattr
    # pylint: disable=attribute-defined-outside-init

    __slots__ = OrderedDict((('size', None), ('uid', None), ('gid', None),
                             ('permissions', None), ('atime', None),
                             ('mtime', None), ('nlink', None),
                             ('extended', [])))

    def _format(self, k, v):
        """Convert attributes to more readable values"""

        if v is None or k == 'extended' and not v:
            return None

        if k == 'permissions':
            return '{:06o}'.format(v)
        elif k in ('atime', 'mtime'):
            return time.ctime(v)
        else:
            return str(v)

    def encode(self):
        """Encode SFTP attributes as bytes in an SSH packet"""

        flags = 0
        attrs = []

        if self.size is not None:
            flags |= FILEXFER_ATTR_SIZE
            attrs.append(UInt64(self.size))

        if self.uid is not None and self.gid is not None:
            flags |= FILEXFER_ATTR_UIDGID
            attrs.append(UInt32(self.uid) + UInt32(self.gid))

        if self.permissions is not None:
            flags |= FILEXFER_ATTR_PERMISSIONS
            attrs.append(UInt32(self.permissions))

        if self.atime is not None and self.mtime is not None:
            flags |= FILEXFER_ATTR_ACMODTIME
            attrs.append(UInt32(int(self.atime)) + UInt32(int(self.mtime)))

        if self.extended:
            flags |= FILEXFER_ATTR_EXTENDED
            attrs.append(UInt32(len(self.extended)))
            attrs.extend(String(type) + String(data)
                         for type, data in self.extended)

        return UInt32(flags) + b''.join(attrs)

    @classmethod
    def decode(cls, packet):
        """Decode bytes in an SSH packet as SFTP attributes"""

        flags = packet.get_uint32()
        attrs = cls()

        if flags & FILEXFER_ATTR_UNDEFINED:
            raise SFTPError(FX_BAD_MESSAGE, 'Unsupported attribute flags')

        if flags & FILEXFER_ATTR_SIZE:
            attrs.size = packet.get_uint64()

        if flags & FILEXFER_ATTR_UIDGID:
            attrs.uid = packet.get_uint32()
            attrs.gid = packet.get_uint32()

        if flags & FILEXFER_ATTR_PERMISSIONS:
            attrs.permissions = packet.get_uint32()

        if flags & FILEXFER_ATTR_ACMODTIME:
            attrs.atime = packet.get_uint32()
            attrs.mtime = packet.get_uint32()

        if flags & FILEXFER_ATTR_EXTENDED:
            count = packet.get_uint32()
            attrs.extended = []

            for _ in range(count):
                attr = packet.get_string()
                data = packet.get_string()
                attrs.extended.append((attr, data))

        return attrs

    @classmethod
    def from_local(cls, result):
        """Convert from local stat attributes"""

        return cls(result.st_size, result.st_uid, result.st_gid,
                   result.st_mode, result.st_atime, result.st_mtime,
                   result.st_nlink)


class SFTPVFSAttrs(Record):
    """SFTP file system attributes

       SFTPVFSAttrs is a simple record class with the following fields:

         ============ =========================================== ======
         Field        Description                                 Type
         ============ =========================================== ======
         bsize        File system block size (I/O size)           uint64
         frsize       Fundamental block size (allocation size)    uint64
         blocks       Total data blocks (in frsize units)         uint64
         bfree        Free data blocks                            uint64
         bavail       Available data blocks (for non-root)        uint64
         files        Total file inodes                           uint64
         ffree        Free file inodes                            uint64
         favail       Available file inodes (for non-root)        uint64
         fsid         File system id                              uint64
         flags        File system flags (read-only, no-setuid)    uint64
         namemax      Maximum filename length                     uint64
         ============ =========================================== ======

    """

    # Unfortunately, pylint can't handle attributes defined with setattr
    # pylint: disable=attribute-defined-outside-init

    __slots__ = OrderedDict((('bsize', 0), ('frsize', 0), ('blocks', 0),
                             ('bfree', 0), ('bavail', 0), ('files', 0),
                             ('ffree', 0), ('favail', 0), ('fsid', 0),
                             ('flags', 0), ('namemax', 0)))

    def encode(self):
        """Encode SFTP statvfs attributes as bytes in an SSH packet"""

        return b''.join((UInt64(self.bsize), UInt64(self.frsize),
                         UInt64(self.blocks), UInt64(self.bfree),
                         UInt64(self.bavail), UInt64(self.files),
                         UInt64(self.ffree), UInt64(self.favail),
                         UInt64(self.fsid), UInt64(self.flags),
                         UInt64(self.namemax)))

    @classmethod
    def decode(cls, packet):
        """Decode bytes in an SSH packet as SFTP statvfs attributes"""

        vfsattrs = cls()

        vfsattrs.bsize = packet.get_uint64()
        vfsattrs.frsize = packet.get_uint64()
        vfsattrs.blocks = packet.get_uint64()
        vfsattrs.bfree = packet.get_uint64()
        vfsattrs.bavail = packet.get_uint64()
        vfsattrs.files = packet.get_uint64()
        vfsattrs.ffree = packet.get_uint64()
        vfsattrs.favail = packet.get_uint64()
        vfsattrs.fsid = packet.get_uint64()
        vfsattrs.flags = packet.get_uint64()
        vfsattrs.namemax = packet.get_uint64()

        return vfsattrs

    @classmethod
    def from_local(cls, result):
        """Convert from local statvfs attributes"""

        return cls(result.f_bsize, result.f_frsize, result.f_blocks,
                   result.f_bfree, result.f_bavail, result.f_files,
                   result.f_ffree, result.f_favail, 0, result.f_flag,
                   result.f_namemax)


class SFTPName(Record):
    """SFTP file name and attributes

       SFTPName is a simple record class with the following fields:

         ========= ================================== ==================
         Field     Description                        Type
         ========= ================================== ==================
         filename  Filename                           `str` or `bytes`
         longname  Expanded form of filename & attrs  `str` or `bytes`
         attrs     File attributes                    :class:`SFTPAttrs`
         ========= ================================== ==================

       A list of these is returned by :meth:`readdir() <SFTPClient.readdir>`
       in :class:`SFTPClient` when retrieving the contents of a directory.

    """

    __slots__ = OrderedDict((('filename', ''), ('longname', ''),
                             ('attrs', SFTPAttrs())))

    def _format(self, k, v):
        """Convert name fields to more readable values"""

        if not v:
            return None

        if k == 'attrs':
            return str(v) or None
        else:
            return v.decode('utf-8', errors='replace') or None

    def encode(self):
        """Encode an SFTP name as bytes in an SSH packet"""


        # pylint: disable=no-member
        return (String(self.filename) + String(self.longname) +
                self.attrs.encode())

    @classmethod
    def decode(cls, packet):
        """Decode bytes in an SSH packet as an SFTP name"""


        filename = packet.get_string()
        longname = packet.get_string()
        attrs = SFTPAttrs.decode(packet)

        return cls(filename, longname, attrs)


class SFTPHandler(SSHPacketLogger):
    """SFTP session handler"""

    _data_pkttypes = {FXP_WRITE, FXP_DATA}

    _handler_names = get_symbol_names(globals(), 'FXP_')

    # SFTP implementations with broken order for SYMLINK arguments
    _nonstandard_symlink_impls = ['OpenSSH', 'paramiko']

    # Return types by message -- unlisted entries always return FXP_STATUS,
    #                            those below return FXP_STATUS on error
    _return_types = {
        FXP_OPEN:                 FXP_HANDLE,
        FXP_READ:                 FXP_DATA,
        FXP_LSTAT:                FXP_ATTRS,
        FXP_FSTAT:                FXP_ATTRS,
        FXP_OPENDIR:              FXP_HANDLE,
        FXP_READDIR:              FXP_NAME,
        FXP_REALPATH:             FXP_NAME,
        FXP_STAT:                 FXP_ATTRS,
        FXP_READLINK:             FXP_NAME,
        b'statvfs@openssh.com':   FXP_EXTENDED_REPLY,
        b'fstatvfs@openssh.com':  FXP_EXTENDED_REPLY
    }

    def __init__(self, reader, writer):
        self._reader = reader
        self._writer = writer

        self._logger = reader.logger.get_child('sftp')

    @property
    def logger(self):
        """A logger associated with this SFTP handler"""

        return self._logger

    @asyncio.coroutine
    def _cleanup(self, exc):
        """Clean up this SFTP session"""

        # pylint: disable=unused-argument

        if self._writer: # pragma: no branch
            self._writer.close()
            self._reader = None
            self._writer = None

    @asyncio.coroutine
    def _process_packet(self, pkttype, pktid, packet):
        """Abstract method for processing SFTP packets"""

        raise NotImplementedError

    def send_packet(self, pkttype, pktid, *args):
        """Send an SFTP packet"""

        payload = Byte(pkttype) + b''.join(args)

        try:
            self._writer.write(UInt32(len(payload)) + payload)
        except ConnectionError as exc:
            raise SFTPError(FX_CONNECTION_LOST, str(exc)) from None

        self.log_sent_packet(pkttype, pktid, payload)

    @asyncio.coroutine
    def recv_packet(self):
        """Receive an SFTP packet"""

        pktlen = yield from self._reader.readexactly(4)
        pktlen = int.from_bytes(pktlen, 'big')

        packet = yield from self._reader.readexactly(pktlen)
        return SSHPacket(packet)

    @asyncio.coroutine
    def recv_packets(self):
        """Receive and process SFTP packets"""

        try:
            while self._reader: # pragma: no branch
                packet = yield from self.recv_packet()

                pkttype = packet.get_byte()
                pktid = packet.get_uint32()

                self.log_received_packet(pkttype, pktid, packet)

                yield from self._process_packet(pkttype, pktid, packet)
        except PacketDecodeError as exc:
            yield from self._cleanup(SFTPError(FX_BAD_MESSAGE, str(exc)))
        except EOFError:
            yield from self._cleanup(None)
        except (OSError, Error) as exc:
            yield from self._cleanup(exc)


class SFTPClientHandler(SFTPHandler):
    """An SFTP client session handler"""

    _extensions = []

    def __init__(self, loop, reader, writer):
        super().__init__(reader, writer)

        self._loop = loop
        self._version = None
        self._next_pktid = 0
        self._requests = {}
        self._nonstandard_symlink = False
        self._supports_posix_rename = False
        self._supports_statvfs = False
        self._supports_fstatvfs = False
        self._supports_hardlink = False
        self._supports_fsync = False

    @asyncio.coroutine
    def _cleanup(self, exc):
        """Clean up this SFTP client session"""

        req_exc = exc or SFTPError(FX_CONNECTION_LOST, 'Connection closed')

        for waiter in self._requests.values():
            if waiter and not waiter.cancelled():
                waiter.set_exception(req_exc)

        self._requests = {}

        self.logger.info('SFTP client exited%s', ': ' + str(exc) if exc else '')

        yield from super()._cleanup(exc)

    @asyncio.coroutine
    def _process_packet(self, pkttype, pktid, packet):
        """Process incoming SFTP responses"""

        try:
            waiter = self._requests.pop(pktid)
        except KeyError:
            yield from self._cleanup(SFTPError(FX_BAD_MESSAGE,
                                               'Invalid response id'))
        else:
            if waiter and not waiter.cancelled():
                waiter.set_result((pkttype, packet))

    def _send_request(self, pkttype, *args, waiter=None):
        """Send an SFTP request"""

        if not self._writer:
            raise SFTPError(FX_NO_CONNECTION, 'Connection not open')

        pktid = self._next_pktid
        self._next_pktid = (self._next_pktid + 1) & 0xffffffff

        self._requests[pktid] = waiter

        if isinstance(pkttype, bytes):
            hdr = UInt32(pktid) + String(pkttype)
            pkttype = FXP_EXTENDED
        else:
            hdr = UInt32(pktid)

        self.send_packet(pkttype, pktid, hdr, *args)

    @asyncio.coroutine
    def _make_request(self, pkttype, *args):
        """Make an SFTP request and wait for a response"""

        waiter = asyncio.Future(loop=self._loop)
        self._send_request(pkttype, *args, waiter=waiter)
        resptype, resp = yield from waiter

        return_type = self._return_types.get(pkttype)

        if resptype not in (FXP_STATUS, return_type):
            raise SFTPError(FX_BAD_MESSAGE,
                            'Unexpected response type: %s' % resptype)

        result = self._packet_handlers[resptype](self, resp)

        if result is not None or return_type is None:
            return result
        else:
            raise SFTPError(FX_BAD_MESSAGE, 'Unexpected FX_OK response')

    def _process_status(self, packet):
        """Process an incoming SFTP status response"""

        # pylint: disable=no-self-use

        code = packet.get_uint32()

        try:
            reason = packet.get_string().decode('utf-8')
            lang = packet.get_string().decode('ascii')
        except UnicodeDecodeError:
            raise SFTPError(FX_BAD_MESSAGE, 'Invalid status message') from None

        packet.check_end()

        if code == FX_OK:
            self.logger.debug1('Received OK')
            return None
        else:
            raise SFTPError(code, reason, lang)

    def _process_handle(self, packet):
        """Process an incoming SFTP handle response"""

        # pylint: disable=no-self-use

        handle = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received handle %s', to_hex(handle))

        return handle

    def _process_data(self, packet):
        """Process an incoming SFTP data response"""

        # pylint: disable=no-self-use

        data = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received %s', plural(len(data), 'data byte'))

        return data

    def _process_name(self, packet):
        """Process an incoming SFTP name response"""

        # pylint: disable=no-self-use

        count = packet.get_uint32()
        names = [SFTPName.decode(packet) for i in range(count)]
        packet.check_end()

        self.logger.debug1('Received %s', plural(len(names), 'name'))

        for name in names:
            self.logger.debug1('  %s', name)

        return names

    def _process_attrs(self, packet):
        """Process an incoming SFTP attributes response"""

        # pylint: disable=no-self-use

        attrs = SFTPAttrs().decode(packet)
        packet.check_end()

        self.logger.debug1('Received %s', attrs)

        return attrs

    def _process_extended_reply(self, packet):
        """Process an incoming SFTP extended reply response"""

        # pylint: disable=no-self-use

        # Let the caller do the decoding for extended replies
        return packet

    _packet_handlers = {
        FXP_STATUS:         _process_status,
        FXP_HANDLE:         _process_handle,
        FXP_DATA:           _process_data,
        FXP_NAME:           _process_name,
        FXP_ATTRS:          _process_attrs,
        FXP_EXTENDED_REPLY: _process_extended_reply
    }

    @asyncio.coroutine
    def start(self):
        """Start an SFTP client"""

        self.logger.debug1('Sending init, version=%d%s', _SFTP_VERSION,
                           ', extensions:' if self._extensions else '')

        for name, data in self._extensions: # pragma: no cover
            self.logger.debug1('  %s: %s', name, data)

        extensions = (String(name) + String(data)
                      for name, data in self._extensions)

        self.send_packet(FXP_INIT, None, UInt32(_SFTP_VERSION), *extensions)

        try:
            resp = yield from self.recv_packet()

            resptype = resp.get_byte()

            self.log_received_packet(resptype, None, resp)

            if resptype != FXP_VERSION:
                raise SFTPError(FX_BAD_MESSAGE, 'Expected version message')

            version = resp.get_uint32()

            if version != _SFTP_VERSION:
                raise SFTPError(FX_BAD_MESSAGE,
                                'Unsupported version: %d' % version)

            self._version = version

            extensions = []

            while resp:
                name = resp.get_string()
                data = resp.get_string()
                extensions.append((name, data))
        except PacketDecodeError as exc:
            raise SFTPError(FX_BAD_MESSAGE, str(exc))
        except (asyncio.IncompleteReadError, Error) as exc:
            raise SFTPError(FX_FAILURE, str(exc))

        self.logger.debug1('Received version=%d%s', version,
                           ', extensions:' if extensions else '')

        for name, data in extensions:
            self.logger.debug1('  %s: %s', name, data)

            if name == b'posix-rename@openssh.com' and data == b'1':
                self._supports_posix_rename = True
            elif name == b'statvfs@openssh.com' and data == b'2':
                self._supports_statvfs = True
            elif name == b'fstatvfs@openssh.com' and data == b'2':
                self._supports_fstatvfs = True
            elif name == b'hardlink@openssh.com' and data == b'1':
                self._supports_hardlink = True
            elif name == b'fsync@openssh.com' and data == b'1':
                self._supports_fsync = True

        if version == 3:
            # Check if the server has a buggy SYMLINK implementation

            server_version = self._reader.get_extra_info('server_version', '')
            if any(name in server_version
                   for name in self._nonstandard_symlink_impls):
                self.logger.debug1('Adjusting for non-standard symlink '
                                   'implementation')
                self._nonstandard_symlink = True

    @asyncio.coroutine
    def open(self, filename, pflags, attrs):
        """Make an SFTP open request"""

        self.logger.debug1('Sending open for %s, mode 0x%02x%s',
                           filename, pflags, hide_empty(attrs))

        return (yield from self._make_request(FXP_OPEN, String(filename),
                                              UInt32(pflags), attrs.encode()))

    @asyncio.coroutine
    def close(self, handle):
        """Make an SFTP close request"""

        self.logger.debug1('Sending close for handle %s', to_hex(handle))

        if self._writer:
            yield from self._make_request(FXP_CLOSE, String(handle))

    def nonblocking_close(self, handle):
        """Send an SFTP close request without blocking on the response"""

        self.logger.debug1('Sending non-blocking close for handle %s',
                           to_hex(handle))

        # Used by context managers, since they can't block to wait for a reply
        if self._writer:
            self._send_request(FXP_CLOSE, String(handle))

    @asyncio.coroutine
    def read(self, handle, offset, length):
        """Make an SFTP read request"""

        self.logger.debug1('Sending read for %s at offset %d in handle %s',
                           plural(length, 'byte'), offset, to_hex(handle))

        return (yield from self._make_request(FXP_READ, String(handle),
                                              UInt64(offset), UInt32(length)))

    @asyncio.coroutine
    def write(self, handle, offset, data):
        """Make an SFTP write request"""

        self.logger.debug1('Sending write for %s at offset %d in handle %s',
                           plural(len(data), 'byte'), offset, to_hex(handle))

        return (yield from self._make_request(FXP_WRITE, String(handle),
                                              UInt64(offset), String(data)))

    @asyncio.coroutine
    def stat(self, path):
        """Make an SFTP stat request"""

        self.logger.debug1('Sending stat for %s', path)

        return (yield from self._make_request(FXP_STAT, String(path)))

    @asyncio.coroutine
    def lstat(self, path):
        """Make an SFTP lstat request"""

        self.logger.debug1('Sending lstat for %s', path)

        return (yield from self._make_request(FXP_LSTAT, String(path)))

    @asyncio.coroutine
    def fstat(self, handle):
        """Make an SFTP fstat request"""

        self.logger.debug1('Sending fstat for handle %s', to_hex(handle))

        return (yield from self._make_request(FXP_FSTAT, String(handle)))

    @asyncio.coroutine
    def setstat(self, path, attrs):
        """Make an SFTP setstat request"""

        self.logger.debug1('Sending setstat for %s%s', path, hide_empty(attrs))

        return (yield from self._make_request(FXP_SETSTAT, String(path),
                                              attrs.encode()))

    @asyncio.coroutine
    def fsetstat(self, handle, attrs):
        """Make an SFTP fsetstat request"""

        self.logger.debug1('Sending fsetstat for handle %s%s',
                           to_hex(handle), hide_empty(attrs))

        return (yield from self._make_request(FXP_FSETSTAT, String(handle),
                                              attrs.encode()))

    @asyncio.coroutine
    def statvfs(self, path):
        """Make an SFTP statvfs request"""

        if self._supports_statvfs:
            self.logger.debug1('Sending statvfs for %s', path)

            packet = yield from self._make_request(b'statvfs@openssh.com',
                                                   String(path))
            vfsattrs = SFTPVFSAttrs.decode(packet)
            packet.check_end()

            self.logger.debug1('Received %s', vfsattrs)

            return vfsattrs
        else:
            raise SFTPError(FX_OP_UNSUPPORTED, 'statvfs not supported')

    @asyncio.coroutine
    def fstatvfs(self, handle):
        """Make an SFTP fstatvfs request"""

        if self._supports_fstatvfs:
            self.logger.debug1('Sending fstatvfs for handle %s', to_hex(handle))

            packet = yield from self._make_request(b'fstatvfs@openssh.com',
                                                   String(handle))
            vfsattrs = SFTPVFSAttrs.decode(packet)
            packet.check_end()

            self.logger.debug1('Received %s', vfsattrs)

            return vfsattrs
        else:
            raise SFTPError(FX_OP_UNSUPPORTED, 'fstatvfs not supported')

    @asyncio.coroutine
    def remove(self, path):
        """Make an SFTP remove request"""

        self.logger.debug1('Sending remove for %s', path)

        return (yield from self._make_request(FXP_REMOVE, String(path)))

    @asyncio.coroutine
    def rename(self, oldpath, newpath):
        """Make an SFTP rename request"""

        self.logger.debug1('Sending rename request from %s to %s',
                           oldpath, newpath)

        return (yield from self._make_request(FXP_RENAME, String(oldpath),
                                              String(newpath)))

    @asyncio.coroutine
    def posix_rename(self, oldpath, newpath):
        """Make an SFTP POSIX rename request"""

        if self._supports_posix_rename:
            self.logger.debug1('Sending POSIX rename request from %s to %s',
                               oldpath, newpath)

            return (yield from self._make_request(b'posix-rename@openssh.com',
                                                  String(oldpath),
                                                  String(newpath)))
        else:
            raise SFTPError(FX_OP_UNSUPPORTED, 'POSIX rename not supported')

    @asyncio.coroutine
    def opendir(self, path):
        """Make an SFTP opendir request"""

        self.logger.debug1('Sending opendir for %s', path)

        return (yield from self._make_request(FXP_OPENDIR, String(path)))

    @asyncio.coroutine
    def readdir(self, handle):
        """Make an SFTP readdir request"""

        self.logger.debug1('Sending readdir for handle %s', to_hex(handle))

        return (yield from self._make_request(FXP_READDIR, String(handle)))

    @asyncio.coroutine
    def mkdir(self, path, attrs):
        """Make an SFTP mkdir request"""

        self.logger.debug1('Sending mkdir for %s', path)

        return (yield from self._make_request(FXP_MKDIR, String(path),
                                              attrs.encode()))

    @asyncio.coroutine
    def rmdir(self, path):
        """Make an SFTP rmdir request"""

        self.logger.debug1('Sending rmdir for %s', path)

        return (yield from self._make_request(FXP_RMDIR, String(path)))

    @asyncio.coroutine
    def realpath(self, path):
        """Make an SFTP realpath request"""

        self.logger.debug1('Sending realpath for %s', path)

        return (yield from self._make_request(FXP_REALPATH, String(path)))

    @asyncio.coroutine
    def readlink(self, path):
        """Make an SFTP readlink request"""

        self.logger.debug1('Sending readlink for %s', path)

        return (yield from self._make_request(FXP_READLINK, String(path)))

    @asyncio.coroutine
    def symlink(self, oldpath, newpath):
        """Make an SFTP symlink request"""

        self.logger.debug1('Sending symlink request from %s to %s',
                           oldpath, newpath)

        if self._nonstandard_symlink:
            args = String(oldpath) + String(newpath)
        else:
            args = String(newpath) + String(oldpath)

        return (yield from self._make_request(FXP_SYMLINK, args))

    @asyncio.coroutine
    def link(self, oldpath, newpath):
        """Make an SFTP link request"""

        if self._supports_hardlink:
            self.logger.debug1('Sending hardlink request from %s to %s',
                               oldpath, newpath)

            return (yield from self._make_request(b'hardlink@openssh.com',
                                                  String(oldpath),
                                                  String(newpath)))
        else:
            raise SFTPError(FX_OP_UNSUPPORTED, 'link not supported')

    @asyncio.coroutine
    def fsync(self, handle):
        """Make an SFTP fsync request"""

        if self._supports_fsync:
            self.logger.debug1('Sending fsync for handle %s', to_hex(handle))

            return (yield from self._make_request(b'fsync@openssh.com',
                                                  String(handle)))
        else:
            raise SFTPError(FX_OP_UNSUPPORTED, 'fsync not supported')

    def exit(self):
        """Handle a request to close the SFTP session"""

        if self._writer:
            self._writer.write_eof()

    @asyncio.coroutine
    def wait_closed(self):
        """Wait for this SFTP session to close"""

        if self._writer:
            yield from self._writer.channel.wait_closed()


class SFTPClientFile:
    """SFTP client remote file object

       This class represents an open file on a remote SFTP server. It
       is opened with the :meth:`open() <SFTPClient.open>` method on the
       :class:`SFTPClient` class and provides methods to read and write
       data and get and set attributes on the open file.

    """

    def __init__(self, loop, handler, handle, appending,
                 encoding, errors, block_size, max_requests):
        self._loop = loop
        self._handler = handler
        self._handle = handle
        self._appending = appending
        self._encoding = encoding
        self._errors = errors
        self._block_size = block_size
        self._max_requests = max_requests
        self._offset = None if appending else 0

    def __enter__(self):
        """Allow SFTPClientFile to be used as a context manager"""

        return self

    def __exit__(self, *exc_info):
        """Automatically close the file when used as a context manager"""

        if self._handle:
            self._handler.nonblocking_close(self._handle)
            self._handle = None

    @asyncio.coroutine
    def __aenter__(self):
        """Allow SFTPClientFile to be used as an async context manager"""

        return self

    @asyncio.coroutine
    def __aexit__(self, *exc_info):
        """Wait for file close when used as an async context manager"""

        yield from self.close()

    @asyncio.coroutine
    def _end(self):
        """Return the offset of the end of the file"""

        attrs = yield from self.stat()
        return attrs.size

    @asyncio.coroutine
    def read(self, size=-1, offset=None):
        """Read data from the remote file

           This method reads and returns up to `size` bytes of data
           from the remote file. If size is negative, all data up to
           the end of the file is returned.

           If offset is specified, the read will be performed starting
           at that offset rather than the current file position. This
           argument should be provided if you want to issue parallel
           reads on the same file, since the file position is not
           predictable in that case.

           Data will be returned as a string if an encoding was set when
           the file was opened. Otherwise, data is returned as bytes.

           An empty `str` or `bytes` object is returned when at EOF.

           :param size:
               The number of bytes to read
           :param offset: (optional)
               The offset from the beginning of the file to begin reading
           :type size: `int`
           :type offset: `int`

           :returns: data read from the file, as a `str` or `bytes`

           :raises: | :exc:`ValueError` if the file has been closed
                    | :exc:`UnicodeDecodeError` if the data can't be
                      decoded using the requested encoding
                    | :exc:`SFTPError` if the server returns an error

        """

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        if offset is None:
            offset = self._offset

        # If self._offset is None, we're appending and haven't seeked
        # backward in the file since the last write, so there's no
        # data to return

        data = b''

        if offset is not None:
            if size is None or size < 0:
                size = (yield from self._end()) - offset

            try:
                if self._block_size and size > self._block_size:
                    data = yield from _SFTPFileReader(
                        self._loop, self._block_size, self._max_requests,
                        self._handler, self._handle, offset, size).run()
                else:
                    data = yield from self._handler.read(self._handle,
                                                         offset, size)
                self._offset = offset + len(data)
            except SFTPError as exc:
                if exc.code != FX_EOF:
                    raise

        if self._encoding:
            data = data.decode(self._encoding, self._errors)

        return data

    @asyncio.coroutine
    def write(self, data, offset=None):
        """Write data to the remote file

           This method writes the specified data at the current
           position in the remote file.

           :param data:
               The data to write to the file
           :param offset: (optional)
               The offset from the beginning of the file to begin writing
           :type data: `str` or `bytes`
           :type offset: `int`

           If offset is specified, the write will be performed starting
           at that offset rather than the current file position. This
           argument should be provided if you want to issue parallel
           writes on the same file, since the file position is not
           predictable in that case.

           :returns: number of bytes written

           :raises: | :exc:`ValueError` if the file has been closed
                    | :exc:`UnicodeEncodeError` if the data can't be
                      encoded using the requested encoding
                    | :exc:`SFTPError` if the server returns an error

        """

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        if offset is None:
            # Offset is ignored when appending, so fill in an offset of 0
            # if we don't have a current file position
            offset = self._offset or 0

        if self._encoding:
            data = data.encode(self._encoding, self._errors)

        datalen = len(data)

        if self._block_size and datalen > self._block_size:
            yield from _SFTPFileWriter(
                self._loop, self._block_size, self._max_requests,
                self._handler, self._handle, offset, data).run()
        else:
            yield from self._handler.write(self._handle, offset, data)

        self._offset = None if self._appending else offset + datalen
        return datalen

    @asyncio.coroutine
    def seek(self, offset, from_what=SEEK_SET):
        """Seek to a new position in the remote file

           This method changes the position in the remote file. The
           `offset` passed in is treated as relative to the beginning
           of the file if `from_what` is set to `SEEK_SET` (the
           default), relative to the current file position if it is
           set to `SEEK_CUR`, or relative to the end of the file
           if it is set to `SEEK_END`.

           :param offset:
               The amount to seek
           :param from_what: (optional)
               The reference point to use
           :type offset: `int`
           :type from_what: `SEEK_SET`, `SEEK_CUR`, or `SEEK_END`

           :returns: The new byte offset from the beginning of the file

        """

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        if from_what == SEEK_SET:
            self._offset = offset
        elif from_what == SEEK_CUR:
            self._offset += offset
        elif from_what == SEEK_END:
            self._offset = (yield from self._end()) + offset
        else:
            raise ValueError('Invalid reference point')

        return self._offset

    @asyncio.coroutine
    def tell(self):
        """Return the current position in the remote file

           This method returns the current position in the remote file.

           :returns: The current byte offset from the beginning of the file

        """

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        if self._offset is None:
            self._offset = yield from self._end()

        return self._offset

    @asyncio.coroutine
    def stat(self):
        """Return file attributes of the remote file

           This method queries file attributes of the currently open file.

           :returns: An :class:`SFTPAttrs` containing the file attributes

           :raises: :exc:`SFTPError` if the server returns an error

        """

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        return (yield from self._handler.fstat(self._handle))

    @asyncio.coroutine
    def setstat(self, attrs):
        """Set attributes of the remote file

           This method sets file attributes of the currently open file.

           :param attrs:
               File attributes to set on the file
           :type attrs: :class:`SFTPAttrs`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        yield from self._handler.fsetstat(self._handle, attrs)

    @asyncio.coroutine
    def statvfs(self):
        """Return file system attributes of the remote file

           This method queries attributes of the file system containing
           the currently open file.

           :returns: An :class:`SFTPVFSAttrs` containing the file system
                     attributes

           :raises: :exc:`SFTPError` if the server doesn't support this
                    extension or returns an error

        """

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        return (yield from self._handler.fstatvfs(self._handle))

    @asyncio.coroutine
    def truncate(self, size=None):
        """Truncate the remote file to the specified size

           This method changes the remote file's size to the specified
           value. If a size is not provided, the current file position
           is used.

           :param size: (optional)
               The desired size of the file, in bytes
           :type size: `int`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        if size is None:
            size = self._offset

        yield from self.setstat(SFTPAttrs(size=size))

    @asyncio.coroutine
    def chown(self, uid, gid):
        """Change the owner user and group id of the remote file

           This method changes the user and group id of the
           currently open file.

           :param uid:
               The new user id to assign to the file
           :param gid:
               The new group id to assign to the file
           :type uid: `int`
           :type gid: `int`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        yield from self.setstat(SFTPAttrs(uid=uid, gid=gid))

    @asyncio.coroutine
    def chmod(self, mode):
        """Change the file permissions of the remote file

           This method changes the permissions of the currently
           open file.

           :param mode:
               The new file permissions, expressed as an int
           :type mode: `int`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        yield from self.setstat(SFTPAttrs(permissions=mode))

    @asyncio.coroutine
    def utime(self, times=None):
        """Change the access and modify times of the remote file

           This method changes the access and modify times of the
           currently open file. If `times` is not provided,
           the times will be changed to the current time.

           :param times: (optional)
               The new access and modify times, as seconds relative to
               the UNIX epoch
           :type times: tuple of two `int` or `float` values

           :raises: :exc:`SFTPError` if the server returns an error

        """

        # pylint: disable=unpacking-non-sequence
        if times is None:
            atime = mtime = time.time()
        else:
            atime, mtime = times

        yield from self.setstat(SFTPAttrs(atime=atime, mtime=mtime))

    @asyncio.coroutine
    def fsync(self):
        """Force the remote file data to be written to disk"""

        if self._handle is None:
            raise ValueError('I/O operation on closed file')

        yield from self._handler.fsync(self._handle)

    @asyncio.coroutine
    def close(self):
        """Close the remote file"""

        if self._handle:
            yield from self._handler.close(self._handle)
            self._handle = None


class SFTPClient:
    """SFTP client

       This class represents the client side of an SFTP session. It is
       started by calling the :meth:`start_sftp_client()
       <SSHClientConnection.start_sftp_client>` method on the
       :class:`SSHClientConnection` class.

    """

    def __init__(self, loop, handler, path_encoding, path_errors):
        self._loop = loop
        self._handler = handler
        self._path_encoding = path_encoding
        self._path_errors = path_errors
        self._cwd = None

    def __enter__(self):
        """Allow SFTPClient to be used as a context manager"""

        return self

    def __exit__(self, *exc_info):
        """Automatically close the session when used as a context manager"""

        self.exit()

    @asyncio.coroutine
    def __aenter__(self):
        """Allow SFTPClient to be used as an async context manager"""

        return self

    @asyncio.coroutine
    def __aexit__(self, *exc_info):
        """Wait for client close when used as an async context manager"""

        self.__exit__()
        yield from self.wait_closed()

    @property
    def logger(self):
        """A logger associated with this SFTP client"""

        return self._handler.logger

    def encode(self, path):
        """Encode path name using configured path encoding

           This method has no effect if the path is already bytes.

        """

        if isinstance(path, PurePath): # pragma: no branch
            path = str(path)

        if isinstance(path, str):
            if self._path_encoding:
                path = path.encode(self._path_encoding, self._path_errors)
            else:
                raise SFTPError(FX_BAD_MESSAGE, 'Path must be bytes when '
                                'encoding is not set')

        return path

    def decode(self, path, want_string=True):
        """Decode path name using configured path encoding

           This method has no effect if want_string is set to `False`.

        """

        if want_string and self._path_encoding:
            try:
                path = path.decode(self._path_encoding, self._path_errors)
            except UnicodeDecodeError:
                raise SFTPError(FX_BAD_MESSAGE,
                                'Unable to decode name') from None

        return path

    def compose_path(self, path, parent=...):
        """Compose a path

           If parent is not specified, return a path relative to the
           current remote working directory.

        """

        if parent is ...:
            parent = self._cwd

        path = self.encode(path)

        return posixpath.join(parent, path) if parent else path

    @asyncio.coroutine
    def _mode(self, path, statfunc=None):
        """Return the mode of a remote path, or 0 if it can't be accessed"""

        if statfunc is None:
            statfunc = self.stat

        try:
            return (yield from statfunc(path)).permissions
        except SFTPError as exc:
            if exc.code in (FX_NO_SUCH_FILE, FX_PERMISSION_DENIED):
                return 0
            else:
                raise

    @asyncio.coroutine
    def _glob(self, fs, patterns, error_handler):
        """Begin a new glob pattern match"""

        # pylint: disable=no-self-use

        if isinstance(patterns, (str, bytes, PurePath)):
            patterns = [patterns]

        result = []

        for pattern in patterns:
            if not pattern:
                continue

            names = yield from match_glob(fs, fs.encode(pattern), error_handler)

            if isinstance(pattern, (str, PurePath)):
                names = [fs.decode(name) for name in names]

            result.extend(names)

        return result

    @asyncio.coroutine
    def _copy(self, srcfs, dstfs, srcpath, dstpath, preserve, recurse,
              follow_symlinks, block_size, max_requests, progress_handler,
              error_handler):
        """Copy a file, directory, or symbolic link"""

        if follow_symlinks:
            srcattrs = yield from srcfs.stat(srcpath)
        else:
            srcattrs = yield from srcfs.lstat(srcpath)

        try:
            if stat.S_ISDIR(srcattrs.permissions):
                if not recurse:
                    raise SFTPError(FX_FAILURE, '%s is a directory' %
                                    srcpath.decode('utf-8', errors='replace'))

                self.logger.info('  Starting copy of directory %s to %s',
                                 srcpath, dstpath)

                if not (yield from dstfs.isdir(dstpath)):
                    yield from dstfs.mkdir(dstpath)

                names = yield from srcfs.listdir(srcpath)

                for name in names:
                    if name in (b'.', b'..'):
                        continue

                    srcfile = posixpath.join(srcpath, name)
                    dstfile = posixpath.join(dstpath, name)

                    yield from self._copy(srcfs, dstfs, srcfile,
                                          dstfile, preserve, recurse,
                                          follow_symlinks, block_size,
                                          max_requests, progress_handler,
                                          error_handler)

                self.logger.info('  Finished copy of directory %s to %s',
                                 srcpath, dstpath)

            elif stat.S_ISLNK(srcattrs.permissions):
                targetpath = yield from srcfs.readlink(srcpath)

                self.logger.info('  Copying symlink %s to %s', srcpath, dstpath)
                self.logger.info('    Target path: %s', targetpath)

                yield from dstfs.symlink(targetpath, dstpath)
            else:
                self.logger.info('  Copying file %s to %s', srcpath, dstpath)

                yield from _SFTPFileCopier(self._loop, block_size,
                                           max_requests, 0, srcattrs.size,
                                           srcfs, dstfs, srcpath, dstpath,
                                           progress_handler).run()

            if preserve:
                attrs = yield from srcfs.stat(srcpath)

                attrs = SFTPAttrs(permissions=attrs.permissions,
                                  atime=attrs.atime, mtime=attrs.mtime)

                self.logger.info('    Preserving attrs: %s', attrs)

                yield from dstfs.setstat(dstpath, attrs)
        except (OSError, SFTPError) as exc:
            # pylint: disable=attribute-defined-outside-init
            exc.srcpath = srcpath
            exc.dstpath = dstpath

            if error_handler:
                error_handler(exc)
            else:
                raise

    @asyncio.coroutine
    def _begin_copy(self, srcfs, dstfs, srcpaths, dstpath, preserve,
                    recurse, follow_symlinks, block_size, max_requests,
                    progress_handler, error_handler):
        """Begin a new file upload, download, or copy"""

        dst_isdir = dstpath is None or (yield from dstfs.isdir(dstpath))

        if dstpath:
            dstpath = dstfs.encode(dstpath)

        if isinstance(srcpaths, (str, bytes, PurePath)):
            srcpaths = [srcpaths]
        elif not dst_isdir:
            raise SFTPError(FX_FAILURE, '%s must be a directory' %
                            dstpath.decode('utf-8', errors='replace'))

        for srcfile in srcpaths:
            srcfile = srcfs.encode(srcfile)
            filename = posixpath.basename(srcfile)

            if dstpath is None:
                dstfile = filename
            elif dst_isdir:
                dstfile = dstfs.compose_path(filename, parent=dstpath)
            else:
                dstfile = dstpath

            yield from self._copy(srcfs, dstfs, srcfile, dstfile, preserve,
                                  recurse, follow_symlinks, block_size,
                                  max_requests, progress_handler, error_handler)

    @asyncio.coroutine
    def get(self, remotepaths, localpath=None, *, preserve=False,
            recurse=False, follow_symlinks=False, block_size=SFTP_BLOCK_SIZE,
            max_requests=_MAX_SFTP_REQUESTS, progress_handler=None,
            error_handler=None):
        """Download remote files

           This method downloads one or more files or directories from
           the remote system. Either a single remote path or a sequence
           of remote paths to download can be provided.

           When downloading a single file or directory, the local path can
           be either the full path to download data into or the path to an
           existing directory where the data should be placed. In the
           latter case, the base file name from the remote path will be
           used as the local name.

           When downloading multiple files, the local path must refer to
           an existing directory.

           If no local path is provided, the file is downloaded
           into the current local working directory.

           If preserve is `True`, the access and modification times
           and permissions of the original file are set on the
           downloaded file.

           If recurse is `True` and the remote path points at a
           directory, the entire subtree under that directory is
           downloaded.

           If follow_symlinks is set to `True`, symbolic links found
           on the remote system will have the contents of their target
           downloaded rather than creating a local symbolic link. When
           using this option during a recursive download, one needs to
           watch out for links that result in loops.

           The block_size argument specifies the size of read and write
           requests issued when downloading the files, defaulting to 16 KB.

           The max_requests argument specifies the maximum number of
           parallel read or write requests issued, defaulting to 128.

           If progress_handler is specified, it will be called after
           each block of a file is successfully downloaded. The arguments
           passed to this handler will be the source path, destination
           path, bytes downloaded so far, and total bytes in the file
           being downloaded. If multiple source paths are provided or
           recurse is set to `True`, the progress_handler will be
           called consecutively on each file being downloaded.

           If error_handler is specified and an error occurs during
           the download, this handler will be called with the exception
           instead of it being raised. This is intended to primarily be
           used when multiple remote paths are provided or when recurse
           is set to `True`, to allow error information to be collected
           without aborting the download of the remaining files. The
           error handler can raise an exception if it wants the download
           to completely stop. Otherwise, after an error, the download
           will continue starting with the next file.

           :param remotepaths:
               The paths of the remote files or directories to download
           :param localpath: (optional)
               The path of the local file or directory to download into
           :param preserve: (optional)
               Whether or not to preserve the original file attributes
           :param recurse: (optional)
               Whether or not to recursively copy directories
           :param follow_symlinks: (optional)
               Whether or not to follow symbolic links
           :param block_size: (optional)
               The block size to use for file reads and writes
           :param max_requests: (optional)
               The maximum number of parallel read or write requests
           :param progress_handler: (optional)
               The function to call to report download progress
           :param error_handler: (optional)
               The function to call when an error occurs
           :type remotepaths:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`,
               or a sequence of these
           :type localpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type preserve: `bool`
           :type recurse: `bool`
           :type follow_symlinks: `bool`
           :type block_size: `int`
           :type max_requests: `int`
           :type progress_handler: `callable`
           :type error_handler: `callable`

           :raises: | :exc:`OSError` if a local file I/O error occurs
                    | :exc:`SFTPError` if the server returns an error

        """

        self.logger.info('Starting SFTP get of %s to %s',
                         remotepaths, localpath)

        yield from self._begin_copy(self, LocalFile, remotepaths, localpath,
                                    preserve, recurse, follow_symlinks,
                                    block_size, max_requests, progress_handler,
                                    error_handler)

    @asyncio.coroutine
    def put(self, localpaths, remotepath=None, *, preserve=False,
            recurse=False, follow_symlinks=False, block_size=SFTP_BLOCK_SIZE,
            max_requests=_MAX_SFTP_REQUESTS, progress_handler=None,
            error_handler=None):
        """Upload local files

           This method uploads one or more files or directories to the
           remote system. Either a single local path or a sequence of
           local paths to upload can be provided.

           When uploading a single file or directory, the remote path can
           be either the full path to upload data into or the path to an
           existing directory where the data should be placed. In the
           latter case, the base file name from the local path will be
           used as the remote name.

           When uploading multiple files, the remote path must refer to
           an existing directory.

           If no remote path is provided, the file is uploaded into the
           current remote working directory.

           If preserve is `True`, the access and modification times
           and permissions of the original file are set on the
           uploaded file.

           If recurse is `True` and the local path points at a
           directory, the entire subtree under that directory is
           uploaded.

           If follow_symlinks is set to `True`, symbolic links found
           on the local system will have the contents of their target
           uploaded rather than creating a remote symbolic link. When
           using this option during a recursive upload, one needs to
           watch out for links that result in loops.

           The block_size argument specifies the size of read and write
           requests issued when uploading the files, defaulting to 16 KB.

           The max_requests argument specifies the maximum number of
           parallel read or write requests issued, defaulting to 128.

           If progress_handler is specified, it will be called after
           each block of a file is successfully uploaded. The arguments
           passed to this handler will be the source path, destination
           path, bytes uploaded so far, and total bytes in the file
           being uploaded. If multiple source paths are provided or
           recurse is set to `True`, the progress_handler will be
           called consecutively on each file being uploaded.

           If error_handler is specified and an error occurs during
           the upload, this handler will be called with the exception
           instead of it being raised. This is intended to primarily be
           used when multiple local paths are provided or when recurse
           is set to `True`, to allow error information to be collected
           without aborting the upload of the remaining files. The
           error handler can raise an exception if it wants the upload
           to completely stop. Otherwise, after an error, the upload
           will continue starting with the next file.

           :param localpaths:
               The paths of the local files or directories to upload
           :param remotepath: (optional)
               The path of the remote file or directory to upload into
           :param preserve: (optional)
               Whether or not to preserve the original file attributes
           :param recurse: (optional)
               Whether or not to recursively copy directories
           :param follow_symlinks: (optional)
               Whether or not to follow symbolic links
           :param block_size: (optional)
               The block size to use for file reads and writes
           :param max_requests: (optional)
               The maximum number of parallel read or write requests
           :param progress_handler: (optional)
               The function to call to report upload progress
           :param error_handler: (optional)
               The function to call when an error occurs
           :type localpaths:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`,
               or a sequence of these
           :type remotepath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type preserve: `bool`
           :type recurse: `bool`
           :type follow_symlinks: `bool`
           :type block_size: `int`
           :type max_requests: `int`
           :type progress_handler: `callable`
           :type error_handler: `callable`

           :raises: | :exc:`OSError` if a local file I/O error occurs
                    | :exc:`SFTPError` if the server returns an error

        """

        self.logger.info('Starting SFTP put of %s to %s',
                         localpaths, remotepath)

        yield from self._begin_copy(LocalFile, self, localpaths, remotepath,
                                    preserve, recurse, follow_symlinks,
                                    block_size, max_requests, progress_handler,
                                    error_handler)

    @asyncio.coroutine
    def copy(self, srcpaths, dstpath=None, *, preserve=False,
             recurse=False, follow_symlinks=False, block_size=SFTP_BLOCK_SIZE,
             max_requests=_MAX_SFTP_REQUESTS, progress_handler=None,
             error_handler=None):
        """Copy remote files to a new location

           This method copies one or more files or directories on the
           remote system to a new location. Either a single source path
           or a sequence of source paths to copy can be provided.

           When copying a single file or directory, the destination path
           can be either the full path to copy data into or the path to
           an existing directory where the data should be placed. In the
           latter case, the base file name from the source path will be
           used as the destination name.

           When copying multiple files, the destination path must refer
           to an existing remote directory.

           If no destination path is provided, the file is copied into
           the current remote working directory.

           If preserve is `True`, the access and modification times
           and permissions of the original file are set on the
           copied file.

           If recurse is `True` and the source path points at a
           directory, the entire subtree under that directory is
           copied.

           If follow_symlinks is set to `True`, symbolic links found
           in the source will have the contents of their target copied
           rather than creating a copy of the symbolic link. When
           using this option during a recursive copy, one needs to
           watch out for links that result in loops.

           The block_size argument specifies the size of read and write
           requests issued when copying the files, defaulting to 16 KB.

           The max_requests argument specifies the maximum number of
           parallel read or write requests issued, defaulting to 128.

           If progress_handler is specified, it will be called after
           each block of a file is successfully copied. The arguments
           passed to this handler will be the source path, destination
           path, bytes copied so far, and total bytes in the file
           being copied. If multiple source paths are provided or
           recurse is set to `True`, the progress_handler will be
           called consecutively on each file being copied.

           If error_handler is specified and an error occurs during
           the copy, this handler will be called with the exception
           instead of it being raised. This is intended to primarily be
           used when multiple source paths are provided or when recurse
           is set to `True`, to allow error information to be collected
           without aborting the copy of the remaining files. The error
           handler can raise an exception if it wants the copy to
           completely stop. Otherwise, after an error, the copy will
           continue starting with the next file.

           :param srcpaths:
               The paths of the remote files or directories to copy
           :param dstpath: (optional)
               The path of the remote file or directory to copy into
           :param preserve: (optional)
               Whether or not to preserve the original file attributes
           :param recurse: (optional)
               Whether or not to recursively copy directories
           :param follow_symlinks: (optional)
               Whether or not to follow symbolic links
           :param block_size: (optional)
               The block size to use for file reads and writes
           :param max_requests: (optional)
               The maximum number of parallel read or write requests
           :param progress_handler: (optional)
               The function to call to report copy progress
           :param error_handler: (optional)
               The function to call when an error occurs
           :type srcpaths:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`,
               or a sequence of these
           :type dstpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type preserve: `bool`
           :type recurse: `bool`
           :type follow_symlinks: `bool`
           :type block_size: `int`
           :type max_requests: `int`
           :type progress_handler: `callable`
           :type error_handler: `callable`

           :raises: | :exc:`OSError` if a local file I/O error occurs
                    | :exc:`SFTPError` if the server returns an error

        """

        self.logger.info('Starting SFTP remote copy of %s to %s',
                         srcpaths, dstpath)

        yield from self._begin_copy(self, self, srcpaths, dstpath, preserve,
                                    recurse, follow_symlinks, block_size,
                                    max_requests, progress_handler,
                                    error_handler)

    @asyncio.coroutine
    def mget(self, remotepaths, localpath=None, *, preserve=False,
             recurse=False, follow_symlinks=False, block_size=SFTP_BLOCK_SIZE,
             max_requests=_MAX_SFTP_REQUESTS, progress_handler=None,
             error_handler=None):
        """Download remote files with glob pattern match

           This method downloads files and directories from the remote
           system matching one or more glob patterns.

           The arguments to this method are identical to the :meth:`get`
           method, except that the remote paths specified can contain
           wildcard patterns.

        """

        self.logger.info('Starting SFTP mget of %s to %s',
                         remotepaths, localpath)

        matches = yield from self._glob(self, remotepaths, error_handler)

        yield from self._begin_copy(self, LocalFile, matches, localpath,
                                    preserve, recurse, follow_symlinks,
                                    block_size, max_requests, progress_handler,
                                    error_handler)

    @asyncio.coroutine
    def mput(self, localpaths, remotepath=None, *, preserve=False,
             recurse=False, follow_symlinks=False, block_size=SFTP_BLOCK_SIZE,
             max_requests=_MAX_SFTP_REQUESTS, progress_handler=None,
             error_handler=None):
        """Upload local files with glob pattern match

           This method uploads files and directories to the remote
           system matching one or more glob patterns.

           The arguments to this method are identical to the :meth:`put`
           method, except that the local paths specified can contain
           wildcard patterns.

        """

        self.logger.info('Starting SFTP mput of %s to %s',
                         localpaths, remotepath)

        matches = yield from self._glob(LocalFile, localpaths, error_handler)

        yield from self._begin_copy(LocalFile, self, matches, remotepath,
                                    preserve, recurse, follow_symlinks,
                                    block_size, max_requests, progress_handler,
                                    error_handler)

    @asyncio.coroutine
    def mcopy(self, srcpaths, dstpath=None, *, preserve=False,
              recurse=False, follow_symlinks=False, block_size=SFTP_BLOCK_SIZE,
              max_requests=_MAX_SFTP_REQUESTS, progress_handler=None,
              error_handler=None):
        """Download remote files with glob pattern match

           This method copies files and directories on the remote
           system matching one or more glob patterns.

           The arguments to this method are identical to the :meth:`copy`
           method, except that the source paths specified can contain
           wildcard patterns.

        """

        self.logger.info('Starting SFTP remote mcopy of %s to %s',
                         srcpaths, dstpath)

        matches = yield from self._glob(self, srcpaths, error_handler)

        yield from self._begin_copy(self, self, matches, dstpath, preserve,
                                    recurse, follow_symlinks, block_size,
                                    max_requests, progress_handler,
                                    error_handler)

    @asyncio.coroutine
    def glob(self, patterns, error_handler=None):
        """Match remote files against glob patterns

           This method matches remote files against one or more glob
           patterns. Either a single pattern or a sequence of patterns
           can be provided to match against.

           Supported wildcard characters include '*', '?', and
           character ranges in square brackets. In addition, '**'
           can be used to trigger a recursive directory search at
           that point in the pattern, and a trailing slash can be
           used to request that only directories get returned.

           If error_handler is specified and an error occurs during
           the match, this handler will be called with the exception
           instead of it being raised. This is intended to primarily be
           used when multiple patterns are provided to allow error
           information to be collected without aborting the match
           against the remaining patterns. The error handler can raise
           an exception if it wants to completely abort the match.
           Otherwise, after an error, the match will continue starting
           with the next pattern.

           An error will be raised if any of the patterns completely
           fail to match, and this can either stop the match against
           the remaining patterns or be handled by the error_handler
           just like other errors.

           :param patterns:
               Glob patterns to try and match remote files against
           :param error_handler: (optional)
               The function to call when an error occurs
           :type patterns:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`,
               or a sequence of these
           :type error_handler: `callable`

           :raises: :exc:`SFTPError` if the server returns an error
                    or no match is found

        """

        return (yield from self._glob(self, patterns, error_handler))

    @async_context_manager
    def open(self, path, pflags_or_mode=FXF_READ, attrs=SFTPAttrs(),
             encoding='utf-8', errors='strict', block_size=SFTP_BLOCK_SIZE,
             max_requests=_MAX_SFTP_REQUESTS):
        """Open a remote file

           This method opens a remote file and returns an
           :class:`SFTPClientFile` object which can be used to read and
           write data and get and set file attributes.

           The path can be either a `str` or `bytes` value. If it is a
           str, it will be encoded using the file encoding specified
           when the :class:`SFTPClient` was started.

           The following open mode flags are supported:

             ========== ======================================================
             Mode       Description
             ========== ======================================================
             FXF_READ   Open the file for reading.
             FXF_WRITE  Open the file for writing. If both this and FXF_READ
                        are set, open the file for both reading and writing.
             FXF_APPEND Force writes to append data to the end of the file
                        regardless of seek position.
             FXF_CREAT  Create the file if it doesn't exist. Without this,
                        attempts to open a non-existent file will fail.
             FXF_TRUNC  Truncate the file to zero length if it already exists.
             FXF_EXCL   Return an error when trying to open a file which
                        already exists.
             ========== ======================================================

           By default, file data is read and written as strings in UTF-8
           format with strict error checking, but this can be changed
           using the `encoding` and `errors` parameters. To read and
           write data as bytes in binary format, an `encoding` value of
           `None` can be used.

           Instead of these flags, a Python open mode string can also be
           provided. Python open modes map to the above flags as follows:

             ==== =============================================
             Mode Flags
             ==== =============================================
             r    FXF_READ
             w    FXF_WRITE | FXF_CREAT | FXF_TRUNC
             a    FXF_WRITE | FXF_CREAT | FXF_APPEND
             x    FXF_WRITE | FXF_CREAT | FXF_EXCL

             r+   FXF_READ | FXF_WRITE
             w+   FXF_READ | FXF_WRITE | FXF_CREAT | FXF_TRUNC
             a+   FXF_READ | FXF_WRITE | FXF_CREAT | FXF_APPEND
             x+   FXF_READ | FXF_WRITE | FXF_CREAT | FXF_EXCL
             ==== =============================================

           Including a 'b' in the mode causes the `encoding` to be set
           to `None`, forcing all data to be read and written as bytes
           in binary format.

           The attrs argument is used to set initial attributes of the
           file if it needs to be created. Otherwise, this argument is
           ignored.

           The block_size argument specifies the size of parallel read and
           write requests issued on the file. If set to `None`, each read
           or write call will become a single request to the SFTP server.
           Otherwise, read or write calls larger than this size will be
           turned into parallel requests to the server of the requested
           size, defaulting to 16 KB.

               .. note:: The OpenSSH SFTP server will close the connection
                         if it receives a message larger than 256 KB, and
                         limits read requests to returning no more than
                         64 KB. So, when connecting to an OpenSSH SFTP
                         server, it is recommended that the block_size be
                         set below these sizes.

           The max_requests argument specifies the maximum number of
           parallel read or write requests issued, defaulting to 128.

           :param path:
               The name of the remote file to open
           :param pflags_or_mode: (optional)
               The access mode to use for the remote file (see above)
           :param attrs: (optional)
               File attributes to use if the file needs to be created
           :param encoding: (optional)
               The Unicode encoding to use for data read and written
               to the remote file
           :param errors: (optional)
               The error-handling mode if an invalid Unicode byte
               sequence is detected, defaulting to 'strict' which
               raises an exception
           :param block_size: (optional)
               The block size to use for read and write requests
           :param max_requests: (optional)
               The maximum number of parallel read or write requests
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type pflags_or_mode: `int` or `str`
           :type attrs: :class:`SFTPAttrs`
           :type encoding: `str`
           :type errors: `str`
           :type block_size: `int` or `None`
           :type max_requests: `int`

           :returns: An :class:`SFTPClientFile` to use to access the file

           :raises: | :exc:`ValueError` if the mode is not valid
                    | :exc:`SFTPError` if the server returns an error

        """

        if isinstance(pflags_or_mode, str):
            pflags, binary = _mode_to_pflags(pflags_or_mode)

            if binary:
                encoding = None
        else:
            pflags = pflags_or_mode

        path = self.compose_path(path)
        handle = yield from self._handler.open(path, pflags, attrs)

        return SFTPClientFile(self._loop, self._handler, handle,
                              pflags & FXF_APPEND, encoding, errors,
                              block_size, max_requests)

    @asyncio.coroutine
    def stat(self, path):
        """Get attributes of a remote file or directory, following symlinks

           This method queries the attributes of a remote file or
           directory. If the path provided is a symbolic link, the
           returned attributes will correspond to the target of the
           link.

           :param path:
               The path of the remote file or directory to get attributes for
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :returns: An :class:`SFTPAttrs` containing the file attributes

           :raises: :exc:`SFTPError` if the server returns an error

        """

        path = self.compose_path(path)
        return (yield from self._handler.stat(path))

    @asyncio.coroutine
    def lstat(self, path):
        """Get attributes of a remote file, directory, or symlink

           This method queries the attributes of a remote file,
           directory, or symlink. Unlike :meth:`stat`, this method
           returns the attributes of a symlink itself rather than
           the target of that link.

           :param path:
               The path of the remote file, directory, or link to get
               attributes for
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :returns: An :class:`SFTPAttrs` containing the file attributes

           :raises: :exc:`SFTPError` if the server returns an error

        """

        path = self.compose_path(path)
        return (yield from self._handler.lstat(path))

    @asyncio.coroutine
    def setstat(self, path, attrs):
        """Set attributes of a remote file or directory

           This method sets attributes of a remote file or directory.
           If the path provided is a symbolic link, the attributes
           will be set on the target of the link. A subset of the
           fields in `attrs` can be initialized and only those
           attributes will be changed.

           :param path:
               The path of the remote file or directory to set attributes for
           :param attrs:
               File attributes to set
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type attrs: :class:`SFTPAttrs`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        path = self.compose_path(path)
        yield from self._handler.setstat(path, attrs)

    @asyncio.coroutine
    def statvfs(self, path):
        """Get attributes of a remote file system

           This method queries the attributes of the file system containing
           the specified path.

           :param path:
               The path of the remote file system to get attributes for
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :returns: An :class:`SFTPVFSAttrs` containing the file system
                     attributes

           :raises: :exc:`SFTPError` if the server doesn't support this
                    extension or returns an error

        """

        path = self.compose_path(path)
        return (yield from self._handler.statvfs(path))

    @asyncio.coroutine
    def truncate(self, path, size):
        """Truncate a remote file to the specified size

           This method truncates a remote file to the specified size.
           If the path provided is a symbolic link, the target of
           the link will be truncated.

           :param path:
               The path of the remote file to be truncated
           :param size:
               The desired size of the file, in bytes
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type size: `int`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        yield from self.setstat(path, SFTPAttrs(size=size))

    @asyncio.coroutine
    def chown(self, path, uid, gid):
        """Change the owner user and group id of a remote file or directory

           This method changes the user and group id of a remote
           file or directory. If the path provided is a symbolic
           link, the target of the link will be changed.

           :param path:
               The path of the remote file to change
           :param uid:
               The new user id to assign to the file
           :param gid:
               The new group id to assign to the file
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type uid: `int`
           :type gid: `int`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        yield from self.setstat(path, SFTPAttrs(uid=uid, gid=gid))

    @asyncio.coroutine
    def chmod(self, path, mode):
        """Change the file permissions of a remote file or directory

           This method changes the permissions of a remote file or
           directory. If the path provided is a symbolic link, the
           target of the link will be changed.

           :param path:
               The path of the remote file to change
           :param mode:
               The new file permissions, expressed as an int
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type mode: `int`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        yield from self.setstat(path, SFTPAttrs(permissions=mode))

    @asyncio.coroutine
    def utime(self, path, times=None):
        """Change the access and modify times of a remote file or directory

           This method changes the access and modify times of a
           remote file or directory. If `times` is not provided,
           the times will be changed to the current time. If the
           path provided is a symbolic link, the target of the link
           will be changed.

           :param path:
               The path of the remote file to change
           :param times: (optional)
               The new access and modify times, as seconds relative to
               the UNIX epoch
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type times: tuple of two `int` or `float` values

           :raises: :exc:`SFTPError` if the server returns an error

        """

        # pylint: disable=unpacking-non-sequence
        if times is None:
            atime = mtime = time.time()
        else:
            atime, mtime = times

        yield from self.setstat(path, SFTPAttrs(atime=atime, mtime=mtime))

    @asyncio.coroutine
    def exists(self, path):
        """Return if the remote path exists and isn't a broken symbolic link

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return bool((yield from self._mode(path)))

    @asyncio.coroutine
    def lexists(self, path):
        """Return if the remote path exists, without following symbolic links

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return bool((yield from self._mode(path, statfunc=self.lstat)))

    @asyncio.coroutine
    def getatime(self, path):
        """Return the last access time of a remote file or directory

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return (yield from self.stat(path)).atime

    @asyncio.coroutine
    def getmtime(self, path):
        """Return the last modification time of a remote file or directory

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return (yield from self.stat(path)).mtime

    @asyncio.coroutine
    def getsize(self, path):
        """Return the size of a remote file or directory

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return (yield from self.stat(path)).size

    @asyncio.coroutine
    def isdir(self, path):
        """Return if the remote path refers to a directory

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return stat.S_ISDIR((yield from self._mode(path)))

    @asyncio.coroutine
    def isfile(self, path):
        """Return if the remote path refers to a regular file

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return stat.S_ISREG((yield from self._mode(path)))

    @asyncio.coroutine
    def islink(self, path):
        """Return if the remote path refers to a symbolic link

           :param path:
               The remote path to check
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        return stat.S_ISLNK((yield from self._mode(path, statfunc=self.lstat)))

    @asyncio.coroutine
    def remove(self, path):
        """Remove a remote file

           This method removes a remote file or symbolic link.

           :param path:
               The path of the remote file or link to remove
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        path = self.compose_path(path)
        yield from self._handler.remove(path)

    @asyncio.coroutine
    def unlink(self, path):
        """Remove a remote file (see :meth:`remove`)"""

        yield from self.remove(path)

    @asyncio.coroutine
    def rename(self, oldpath, newpath):
        """Rename a remote file, directory, or link

           This method renames a remote file, directory, or link.

           .. note:: This requests the standard SFTP version of rename
                     which will not overwrite the new path if it already
                     exists. To request POSIX behavior where the new
                     path is removed before the rename, use
                     :meth:`posix_rename`.

           :param oldpath:
               The path of the remote file, directory, or link to rename
           :param newpath:
               The new name for this file, directory, or link
           :type oldpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type newpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        oldpath = self.compose_path(oldpath)
        newpath = self.compose_path(newpath)
        yield from self._handler.rename(oldpath, newpath)

    @asyncio.coroutine
    def posix_rename(self, oldpath, newpath):
        """Rename a remote file, directory, or link with POSIX semantics

           This method renames a remote file, directory, or link,
           removing the prior instance of new path if it previously
           existed.

           This method may not be supported by all SFTP servers.

           :param oldpath:
               The path of the remote file, directory, or link to rename
           :param newpath:
               The new name for this file, directory, or link
           :type oldpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type newpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server doesn't support this
                    extension or returns an error

        """

        oldpath = self.compose_path(oldpath)
        newpath = self.compose_path(newpath)
        yield from self._handler.posix_rename(oldpath, newpath)

    @asyncio.coroutine
    def readdir(self, path='.'):
        """Read the contents of a remote directory

           This method reads the contents of a directory, returning
           the names and attributes of what is contained there. If no
           path is provided, it defaults to the current remote working
           directory.

           :param path: (optional)
               The path of the remote directory to read
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :returns: A list of :class:`SFTPName` entries, with path
                     names matching the type used to pass in the path

           :raises: :exc:`SFTPError` if the server returns an error

        """

        names = []

        dirpath = self.compose_path(path)
        handle = yield from self._handler.opendir(dirpath)

        try:
            while True:
                names.extend((yield from self._handler.readdir(handle)))
        except SFTPError as exc:
            if exc.code != FX_EOF:
                raise
        finally:
            yield from self._handler.close(handle)

        if isinstance(path, str):
            for name in names:
                name.filename = self.decode(name.filename)
                name.longname = self.decode(name.longname)

        return names

    @asyncio.coroutine
    def listdir(self, path='.'):
        """Read the names of the files in a remote directory

           This method reads the names of files and subdirectories
           in a remote directory. If no path is provided, it defaults
           to the current remote working directory.

           :param path: (optional)
               The path of the remote directory to read
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :returns: A list of file/subdirectory names, matching the
                     type used to pass in the path

           :raises: :exc:`SFTPError` if the server returns an error

        """

        names = yield from self.readdir(path)
        return [name.filename for name in names]

    @asyncio.coroutine
    def mkdir(self, path, attrs=SFTPAttrs()):
        """Create a remote directory with the specified attributes

           This method creates a new remote directory at the
           specified path with the requested attributes.

           :param path:
               The path of where the new remote directory should be created
           :param attrs: (optional)
               The file attributes to use when creating the directory
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type attrs: :class:`SFTPAttrs`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        path = self.compose_path(path)
        yield from self._handler.mkdir(path, attrs)

    @asyncio.coroutine
    def rmdir(self, path):
        """Remove a remote directory

           This method removes a remote directory. The directory
           must be empty for the removal to succeed.

           :param path:
               The path of the remote directory to remove
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        path = self.compose_path(path)
        yield from self._handler.rmdir(path)

    @asyncio.coroutine
    def realpath(self, path):
        """Return the canonical version of a remote path

           This method returns a canonical version of the requested path.

           :param path: (optional)
               The path of the remote directory to canonicalize
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :returns: The canonical path as a `str` or `bytes`, matching
                     the type used to pass in the path

           :raises: :exc:`SFTPError` if the server returns an error

        """

        fullpath = self.compose_path(path)
        names = yield from self._handler.realpath(fullpath)

        if len(names) > 1:
            raise SFTPError(FX_BAD_MESSAGE, 'Too many names returned')

        return self.decode(names[0].filename, isinstance(path, (str, PurePath)))

    @asyncio.coroutine
    def getcwd(self):
        """Return the current remote working directory

           :returns: The current remote working directory, decoded using
                     the specified path encoding

           :raises: :exc:`SFTPError` if the server returns an error

        """

        if self._cwd is None:
            self._cwd = yield from self.realpath(b'.')

        return self.decode(self._cwd)

    @asyncio.coroutine
    def chdir(self, path):
        """Change the current remote working directory

           :param path:
               The path to set as the new remote working directory
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        self._cwd = yield from self.realpath(self.encode(path))

    @asyncio.coroutine
    def readlink(self, path):
        """Return the target of a remote symbolic link

           This method returns the target of a symbolic link.

           :param path:
               The path of the remote symbolic link to follow
           :type path: :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :returns: The target path of the link as a `str` or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        linkpath = self.compose_path(path)
        names = yield from self._handler.readlink(linkpath)

        if len(names) > 1:
            raise SFTPError(FX_BAD_MESSAGE, 'Too many names returned')

        return self.decode(names[0].filename, isinstance(path, str))

    @asyncio.coroutine
    def symlink(self, oldpath, newpath):
        """Create a remote symbolic link

           This method creates a symbolic link. The argument order here
           matches the standard Python :meth:`os.symlink` call. The
           argument order sent on the wire is automatically adapted
           depending on the version information sent by the server, as
           a number of servers (OpenSSH in particular) did not follow
           the SFTP standard when implementing this call.

           :param oldpath:
               The path the link should point to
           :param newpath:
               The path of where to create the remote symbolic link
           :type oldpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type newpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server returns an error

        """

        oldpath = self.compose_path(oldpath)
        newpath = self.encode(newpath)
        yield from self._handler.symlink(oldpath, newpath)

    @asyncio.coroutine
    def link(self, oldpath, newpath):
        """Create a remote hard link

           This method creates a hard link to the remote file specified
           by oldpath at the location specified by newpath.

           This method may not be supported by all SFTP servers.

           :param oldpath:
               The path of the remote file the hard link should point to
           :param newpath:
               The path of where to create the remote hard link
           :type oldpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`
           :type newpath:
               :class:`PurePath <pathlib.PurePath>`, `str`, or `bytes`

           :raises: :exc:`SFTPError` if the server doesn't support this
                    extension or returns an error

        """

        oldpath = self.compose_path(oldpath)
        newpath = self.compose_path(newpath)
        yield from self._handler.link(oldpath, newpath)

    def exit(self):
        """Exit the SFTP client session

           This method exits the SFTP client session, closing the
           corresponding channel opened on the server.

        """

        self._handler.exit()

    @asyncio.coroutine
    def wait_closed(self):
        """Wait for this SFTP client session to close"""

        yield from self._handler.wait_closed()


class SFTPServerHandler(SFTPHandler):
    """An SFTP server session handler"""

    _extensions = [(b'posix-rename@openssh.com', b'1'),
                   (b'hardlink@openssh.com', b'1'),
                   (b'fsync@openssh.com', b'1')]

    if hasattr(os, 'statvfs'): # pragma: no branch
        _extensions += [(b'statvfs@openssh.com', b'2'),
                        (b'fstatvfs@openssh.com', b'2')]

    def __init__(self, server, reader, writer):
        super().__init__(reader, writer)

        self._server = server
        self._version = None
        self._nonstandard_symlink = False
        self._next_handle = 0
        self._file_handles = {}
        self._dir_handles = {}

    @asyncio.coroutine
    def _cleanup(self, exc):
        """Clean up this SFTP server session"""

        if self._server: # pragma: no branch
            for file_obj in self._file_handles.values():
                result = self._server.close(file_obj)

                if asyncio.iscoroutine(result):
                    yield from result

            result = self._server.exit()

            if asyncio.iscoroutine(result):
                yield from result

            self._server = None
            self._file_handles = []
            self._dir_handles = []

        self.logger.info('SFTP server exited%s', ': ' + str(exc) if exc else '')

        yield from super()._cleanup(exc)

    def _get_next_handle(self):
        """Get the next available unique file handle number"""

        while True:
            handle = self._next_handle.to_bytes(4, 'big')
            self._next_handle = (self._next_handle + 1) & 0xffffffff

            if (handle not in self._file_handles and
                    handle not in self._dir_handles):
                return handle

    @asyncio.coroutine
    def _process_packet(self, pkttype, pktid, packet):
        """Process incoming SFTP requests"""

        # pylint: disable=broad-except
        try:
            if pkttype == FXP_EXTENDED:
                pkttype = packet.get_string()

            handler = self._packet_handlers.get(pkttype)
            if not handler:
                raise SFTPError(FX_OP_UNSUPPORTED,
                                'Unsupported request type: %s' % pkttype)

            return_type = self._return_types.get(pkttype, FXP_STATUS)
            result = yield from handler(self, packet)

            if return_type == FXP_STATUS:
                self.logger.debug1('Sending OK')

                result = UInt32(FX_OK) + String('') + String('')
            elif return_type == FXP_HANDLE:
                self.logger.debug1('Sending handle %s', to_hex(result))

                result = String(result)
            elif return_type == FXP_DATA:
                self.logger.debug1('Sending %s', plural(len(result),
                                                        'data byte'))

                result = String(result)
            elif return_type == FXP_NAME:
                self.logger.debug1('Sending %s', plural(len(result), 'name'))

                for name in result:
                    self.logger.debug1('  %s', name)

                result = (UInt32(len(result)) +
                          b''.join(name.encode() for name in result))
            else:
                if isinstance(result, os.stat_result):
                    result = SFTPAttrs.from_local(result)
                elif isinstance(result, os.statvfs_result):
                    result = SFTPVFSAttrs.from_local(result)

                if isinstance(result, SFTPAttrs):
                    self.logger.debug1('Sending %s', result)
                elif isinstance(result, SFTPVFSAttrs): # pragma: no branch
                    self.logger.debug1('Sending %s', result)

                result = result.encode()
        except PacketDecodeError as exc:
            return_type = FXP_STATUS

            self.logger.debug1('Sending bad message error: %s', str(exc))

            result = (UInt32(FX_BAD_MESSAGE) + String(str(exc)) +
                      String(DEFAULT_LANG))
        except SFTPError as exc:
            return_type = FXP_STATUS

            if exc.code == FX_EOF:
                self.logger.debug1('Sending EOF')
            else:
                self.logger.debug1('Sending error: %s', str(exc.reason))

            result = UInt32(exc.code) + String(exc.reason) + String(exc.lang)
        except NotImplementedError as exc:
            return_type = FXP_STATUS
            name = handler.__name__[9:]

            self.logger.debug1('Sending operation not supported: %s', name)

            result = (UInt32(FX_OP_UNSUPPORTED) +
                      String('Operation not supported: %s' % name) +
                      String(DEFAULT_LANG))
        except OSError as exc:
            return_type = FXP_STATUS
            reason = exc.strerror or str(exc)

            if exc.errno in (errno.ENOENT, errno.ENOTDIR):
                self.logger.debug1('Sending no such file error: %s', reason)

                code = FX_NO_SUCH_FILE
            elif exc.errno == errno.EACCES:
                self.logger.debug1('Sending permission denied: %s', reason)

                code = FX_PERMISSION_DENIED
            else:
                self.logger.debug1('Sending failure: %s', reason)

                code = FX_FAILURE

            result = UInt32(code) + String(reason) + String(DEFAULT_LANG)
        except Exception as exc: # pragma: no cover
            return_type = FXP_STATUS
            reason = 'Uncaught exception: %s' % str(exc)

            self.logger.debug1('Sending failure: %s', reason)

            result = UInt32(FX_FAILURE) + String(reason) + String(DEFAULT_LANG)

        self.send_packet(return_type, pktid, UInt32(pktid), result)

    @asyncio.coroutine
    def _process_open(self, packet):
        """Process an incoming SFTP open request"""

        path = packet.get_string()
        pflags = packet.get_uint32()
        attrs = SFTPAttrs.decode(packet)
        packet.check_end()

        self.logger.debug1('Received open request for %s, mode 0x%02x%s',
                           path, pflags, hide_empty(attrs))

        result = self._server.open(path, pflags, attrs)

        if asyncio.iscoroutine(result):
            result = yield from result

        handle = self._get_next_handle()
        self._file_handles[handle] = result
        return handle

    @asyncio.coroutine
    def _process_close(self, packet):
        """Process an incoming SFTP close request"""

        handle = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received close for handle %s', to_hex(handle))

        file_obj = self._file_handles.pop(handle, None)
        if file_obj:
            result = self._server.close(file_obj)

            if asyncio.iscoroutine(result):
                yield from result

            return

        if self._dir_handles.pop(handle, None) is not None:
            return

        raise SFTPError(FX_FAILURE, 'Invalid file handle')

    @asyncio.coroutine
    def _process_read(self, packet):
        """Process an incoming SFTP read request"""

        handle = packet.get_string()
        offset = packet.get_uint64()
        length = packet.get_uint32()
        packet.check_end()

        self.logger.debug1('Received read for %s at offset %d in handle %s',
                           plural(length, 'byte'), offset, to_hex(handle))

        file_obj = self._file_handles.get(handle)

        if file_obj:
            result = self._server.read(file_obj, offset, length)

            if asyncio.iscoroutine(result):
                result = yield from result

            if result:
                return result
            else:
                raise SFTPError(FX_EOF, '')
        else:
            raise SFTPError(FX_FAILURE, 'Invalid file handle')

    @asyncio.coroutine
    def _process_write(self, packet):
        """Process an incoming SFTP write request"""

        handle = packet.get_string()
        offset = packet.get_uint64()
        data = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received write for %s at offset %d in handle %s',
                           plural(len(data), 'byte'), offset, to_hex(handle))

        file_obj = self._file_handles.get(handle)

        if file_obj:
            result = self._server.write(file_obj, offset, data)

            if asyncio.iscoroutine(result):
                result = yield from result

            return result
        else:
            raise SFTPError(FX_FAILURE, 'Invalid file handle')

    @asyncio.coroutine
    def _process_lstat(self, packet):
        """Process an incoming SFTP lstat request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received lstat for %s', path)

        result = self._server.lstat(path)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_fstat(self, packet):
        """Process an incoming SFTP fstat request"""

        handle = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received fstat for handle %s', to_hex(handle))

        file_obj = self._file_handles.get(handle)

        if file_obj:
            result = self._server.fstat(file_obj)

            if asyncio.iscoroutine(result):
                result = yield from result

            return result
        else:
            raise SFTPError(FX_FAILURE, 'Invalid file handle')

    @asyncio.coroutine
    def _process_setstat(self, packet):
        """Process an incoming SFTP setstat request"""

        path = packet.get_string()
        attrs = SFTPAttrs.decode(packet)
        packet.check_end()

        self.logger.debug1('Received setstat for %s%s', path, hide_empty(attrs))

        result = self._server.setstat(path, attrs)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_fsetstat(self, packet):
        """Process an incoming SFTP fsetstat request"""

        handle = packet.get_string()
        attrs = SFTPAttrs.decode(packet)
        packet.check_end()

        self.logger.debug1('Received fsetstat for handle %s%s',
                           to_hex(handle), hide_empty(attrs))

        file_obj = self._file_handles.get(handle)

        if file_obj:
            result = self._server.fsetstat(file_obj, attrs)

            if asyncio.iscoroutine(result):
                result = yield from result

            return result
        else:
            raise SFTPError(FX_FAILURE, 'Invalid file handle')

    @asyncio.coroutine
    def _process_opendir(self, packet):
        """Process an incoming SFTP opendir request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received opendir for %s', path)

        listdir_result = self._server.listdir(path)

        if asyncio.iscoroutine(listdir_result):
            listdir_result = yield from listdir_result

        for i, name in enumerate(listdir_result):
            # pylint: disable=no-member

            if isinstance(name, bytes):
                name = SFTPName(name)
                listdir_result[i] = name

                # pylint: disable=attribute-defined-outside-init

                filename = os.path.join(path, name.filename)
                attr_result = self._server.lstat(filename)

                if asyncio.iscoroutine(attr_result):
                    attr_result = yield from attr_result

                if isinstance(attr_result, os.stat_result):
                    attr_result = SFTPAttrs.from_local(attr_result)

                name.attrs = attr_result

            if not name.longname:
                longname_result = self._server.format_longname(name)

                if asyncio.iscoroutine(longname_result):
                    yield from longname_result

        handle = self._get_next_handle()
        self._dir_handles[handle] = listdir_result
        return handle

    @asyncio.coroutine
    def _process_readdir(self, packet):
        """Process an incoming SFTP readdir request"""

        handle = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received readdir for handle %s', to_hex(handle))

        names = self._dir_handles.get(handle)
        if names:
            result = names[:_MAX_READDIR_NAMES]
            del names[:_MAX_READDIR_NAMES]
            return result
        else:
            raise SFTPError(FX_EOF, '')

    @asyncio.coroutine
    def _process_remove(self, packet):
        """Process an incoming SFTP remove request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received remove for %s', path)

        result = self._server.remove(path)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_mkdir(self, packet):
        """Process an incoming SFTP mkdir request"""

        path = packet.get_string()
        attrs = SFTPAttrs.decode(packet)
        packet.check_end()

        self.logger.debug1('Received mkdir for %s', path)

        result = self._server.mkdir(path, attrs)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_rmdir(self, packet):
        """Process an incoming SFTP rmdir request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received rmdir for %s', path)

        result = self._server.rmdir(path)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_realpath(self, packet):
        """Process an incoming SFTP realpath request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received realpath for %s', path)

        result = self._server.realpath(path)

        if asyncio.iscoroutine(result):
            result = yield from result

        return [SFTPName(result)]

    @asyncio.coroutine
    def _process_stat(self, packet):
        """Process an incoming SFTP stat request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received stat for %s', path)

        result = self._server.stat(path)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_rename(self, packet):
        """Process an incoming SFTP rename request"""

        oldpath = packet.get_string()
        newpath = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received rename request from %s to %s',
                           oldpath, newpath)

        result = self._server.rename(oldpath, newpath)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_readlink(self, packet):
        """Process an incoming SFTP readlink request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received readlink for %s', path)

        result = self._server.readlink(path)

        if asyncio.iscoroutine(result):
            result = yield from result

        return [SFTPName(result)]

    @asyncio.coroutine
    def _process_symlink(self, packet):
        """Process an incoming SFTP symlink request"""

        if self._nonstandard_symlink:
            oldpath = packet.get_string()
            newpath = packet.get_string()
        else:
            newpath = packet.get_string()
            oldpath = packet.get_string()

        packet.check_end()

        self.logger.debug1('Received symlink request from %s to %s',
                           oldpath, newpath)

        result = self._server.symlink(oldpath, newpath)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_posix_rename(self, packet):
        """Process an incoming SFTP POSIX rename request"""

        oldpath = packet.get_string()
        newpath = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received POSIX rename request from %s to %s',
                           oldpath, newpath)

        result = self._server.posix_rename(oldpath, newpath)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_statvfs(self, packet):
        """Process an incoming SFTP statvfs request"""

        path = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received statvfs for %s', path)

        result = self._server.statvfs(path)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_fstatvfs(self, packet):
        """Process an incoming SFTP fstatvfs request"""

        handle = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received fstatvfs for handle %s', to_hex(handle))

        file_obj = self._file_handles.get(handle)

        if file_obj:
            result = self._server.fstatvfs(file_obj)

            if asyncio.iscoroutine(result):
                result = yield from result

            return result
        else:
            raise SFTPError(FX_FAILURE, 'Invalid file handle')

    @asyncio.coroutine
    def _process_link(self, packet):
        """Process an incoming SFTP hard link request"""

        oldpath = packet.get_string()
        newpath = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received hardlink request from %s to %s',
                           oldpath, newpath)

        result = self._server.link(oldpath, newpath)

        if asyncio.iscoroutine(result):
            result = yield from result

        return result

    @asyncio.coroutine
    def _process_fsync(self, packet):
        """Process an incoming SFTP fsync request"""

        handle = packet.get_string()
        packet.check_end()

        self.logger.debug1('Received fsync for handle %s', to_hex(handle))

        file_obj = self._file_handles.get(handle)

        if file_obj:
            result = self._server.fsync(file_obj)

            if asyncio.iscoroutine(result):
                result = yield from result

            return result
        else:
            raise SFTPError(FX_FAILURE, 'Invalid file handle')

    _packet_handlers = {
        FXP_OPEN:                     _process_open,
        FXP_CLOSE:                    _process_close,
        FXP_READ:                     _process_read,
        FXP_WRITE:                    _process_write,
        FXP_LSTAT:                    _process_lstat,
        FXP_FSTAT:                    _process_fstat,
        FXP_SETSTAT:                  _process_setstat,
        FXP_FSETSTAT:                 _process_fsetstat,
        FXP_OPENDIR:                  _process_opendir,
        FXP_READDIR:                  _process_readdir,
        FXP_REMOVE:                   _process_remove,
        FXP_MKDIR:                    _process_mkdir,
        FXP_RMDIR:                    _process_rmdir,
        FXP_REALPATH:                 _process_realpath,
        FXP_STAT:                     _process_stat,
        FXP_RENAME:                   _process_rename,
        FXP_READLINK:                 _process_readlink,
        FXP_SYMLINK:                  _process_symlink,
        b'posix-rename@openssh.com':  _process_posix_rename,
        b'statvfs@openssh.com':       _process_statvfs,
        b'fstatvfs@openssh.com':      _process_fstatvfs,
        b'hardlink@openssh.com':      _process_link,
        b'fsync@openssh.com':         _process_fsync
    }

    @asyncio.coroutine
    def run(self):
        """Run an SFTP server"""

        try:
            packet = yield from self.recv_packet()

            pkttype = packet.get_byte()

            self.log_received_packet(pkttype, None, packet)

            version = packet.get_uint32()

            extensions = []

            while packet:
                name = packet.get_string()
                data = packet.get_string()
                extensions.append((name, data))
        except PacketDecodeError as exc:
            yield from self._cleanup(SFTPError(FX_BAD_MESSAGE, str(exc)))
            return
        except Error as exc:
            yield from self._cleanup(exc)
            return

        if pkttype != FXP_INIT:
            yield from self._cleanup(SFTPError(FX_BAD_MESSAGE,
                                               'Expected init message'))
            return

        self.logger.debug1('Received init, version=%d%s', version,
                           ', extensions:' if extensions else '')

        for name, data in extensions:
            self.logger.debug1('  %s: %s', name, data)

        reply_version = min(version, _SFTP_VERSION)

        self.logger.debug1('Sending version=%d%s', reply_version,
                           ', extensions:' if self._extensions else '')

        for name, data in self._extensions:
            self.logger.debug1('  %s: %s', name, data)

        extensions = (String(name) + String(data)
                      for name, data in self._extensions)

        try:
            self.send_packet(FXP_VERSION, None, UInt32(reply_version),
                             *extensions)
        except SFTPError as exc:
            yield from self._cleanup(exc)
            return

        if reply_version == 3:
            # Check if the server has a buggy SYMLINK implementation

            client_version = self._reader.get_extra_info('client_version', '')
            if any(name in client_version
                   for name in self._nonstandard_symlink_impls):
                self.logger.debug1('Adjusting for non-standard symlink '
                                   'implementation')
                self._nonstandard_symlink = True

        yield from self.recv_packets()


class SFTPServer:
    """SFTP server

       Applications should subclass this when implementing an SFTP
       server. The methods listed below should be implemented to
       provide the desired application behavior.

           .. note:: Any method can optionally be defined as a
                     coroutine if that method needs to perform
                     blocking opertions to determine its result.

       The `conn` object provided here refers to the
       :class:`SSHServerConnection` instance this SFTP server is
       associated with. It can be queried to determine which user
       the client authenticated as or to request key and certificate
       options or permissions which should be applied to this session.

       If the `chroot` argument is specified when this object is
       created, the default :meth:`map_path` and :meth:`reverse_map_path`
       methods will enforce a virtual root directory starting in that
       location, limiting access to only files within that directory
       tree. This will also affect path names returned by the
       :meth:`realpath` and :meth:`readlink` methods.

    """

    # The default implementation of a number of these methods don't need self
    # pylint: disable=no-self-use

    def __init__(self, conn, chroot=None):
        # pylint: disable=unused-argument

        if chroot:
            self._chroot = _from_local_path(os.path.realpath(chroot))
        else:
            self._chroot = None

    @classmethod
    def new(cls, chan):
        """Allocate a new SFTP server"""

        # Make channel, connection, and env available as properties on
        # this SFTP server even before __init__ is called, but continue
        # to pass "conn" as an explicit argument for backward compatibility
        # with older code which is expecting that.

        sftp_server = cls.__new__(cls)
        sftp_server.channel = chan

        sftp_server.__init__(chan.get_connection())

        return sftp_server

    @property
    def channel(self):
        """The channel associated with this SFTP server session"""

        return self._chan

    @channel.setter
    def channel(self, chan):
        """Set the channel associated with this SFTP server session"""

        # pylint: disable=attribute-defined-outside-init

        self._chan = chan

    @property
    def connection(self):
        """The channel associated with this SFTP server session"""

        return self._chan.get_connection()

    @property
    def env(self):
        """The environment associated with this SFTP server session

           This method returns the environment set by the client
           when this SFTP session was opened.

           :returns: A dictionary containing the environment variables
                     set by the client

        """


        return self._chan.get_environment()

    @property
    def logger(self):
        """A logger associated with this SFTP server"""

        return self._chan.logger

    def format_user(self, uid):
        """Return the user name associated with a uid

           This method returns a user name string to insert into
           the `longname` field of an :class:`SFTPName` object.

           By default, it calls the Python :func:`pwd.getpwuid`
           function if it is available, or returns the numeric
           uid as a string if not. If there is no uid, it returns
           an empty string.

           :param uid:
               The uid value to look up
           :type uid: `int` or `None`

           :returns: The formatted user name string

        """

        if uid is not None:
            try:
                import pwd
                user = pwd.getpwuid(uid).pw_name
            except (ImportError, KeyError):
                user = str(uid)
        else:
            user = ''

        return user


    def format_group(self, gid):
        """Return the group name associated with a gid

           This method returns a group name string to insert into
           the `longname` field of an :class:`SFTPName` object.

           By default, it calls the Python :func:`grp.getgrgid`
           function if it is available, or returns the numeric
           gid as a string if not. If there is no gid, it returns
           an empty string.

           :param gid:
               The gid value to look up
           :type gid: `int` or `None`

           :returns: The formatted group name string

        """

        if gid is not None:
            try:
                import grp
                group = grp.getgrgid(gid).gr_name
            except (ImportError, KeyError):
                group = str(gid)
        else:
            group = ''

        return group


    def format_longname(self, name):
        """Format the long name associated with an SFTP name

           This method fills in the `longname` field of a
           :class:`SFTPName` object. By default, it generates
           something similar to UNIX "ls -l" output. The `filename`
           and `attrs` fields of the :class:`SFTPName` should
           already be filled in before this method is called.

           :param name:
               The :class:`SFTPName` instance to format the long name for
           :type name: :class:`SFTPName`

        """

        if name.attrs.permissions is not None:
            mode = stat.filemode(name.attrs.permissions)
        else:
            mode = ''

        nlink = str(name.attrs.nlink) if name.attrs.nlink else ''

        user = self.format_user(name.attrs.uid)
        group = self.format_group(name.attrs.gid)

        size = str(name.attrs.size) if name.attrs.size is not None else ''

        if name.attrs.mtime is not None:
            now = time.time()
            mtime = time.localtime(name.attrs.mtime)
            modtime = time.strftime('%b ', mtime)

            try:
                modtime += time.strftime('%e', mtime)
            except ValueError:
                modtime += time.strftime('%d', mtime)

            if now - 365*24*60*60/2 < name.attrs.mtime <= now:
                modtime += time.strftime(' %H:%M', mtime)
            else:
                modtime += time.strftime('  %Y', mtime)
        else:
            modtime = ''

        detail = '{:10s} {:>4s} {:8s} {:8s} {:>8s} {:12s} '.format(
            mode, nlink, user, group, size, modtime)

        name.longname = detail.encode('utf-8') + name.filename

    def map_path(self, path):
        """Map the path requested by the client to a local path

           This method can be overridden to provide a custom mapping
           from path names requested by the client to paths in the local
           filesystem. By default, it will enforce a virtual "chroot"
           if one was specified when this server was created. Otherwise,
           path names are left unchanged, with relative paths being
           interpreted based on the working directory of the currently
           running process.

           :param path:
               The path name to map
           :type path: `bytes`

           :returns: bytes containing the local path name to operate on

        """

        if self._chroot:
            normpath = posixpath.normpath(os.path.join(b'/', path))
            return posixpath.join(self._chroot, normpath[1:])
        else:
            return path

    def reverse_map_path(self, path):
        """Reverse map a local path into the path reported to the client

           This method can be overridden to provide a custom reverse
           mapping for the mapping provided by :meth:`map_path`. By
           default, it hides the portion of the local path associated
           with the virtual "chroot" if one was specified.

           :param path:
               The local path name to reverse map
           :type path: `bytes`

           :returns: bytes containing the path name to report to the client

        """

        if self._chroot:
            if path == self._chroot:
                return b'/'
            elif path.startswith(self._chroot + b'/'):
                return path[len(self._chroot):]
            else:
                raise SFTPError(FX_NO_SUCH_FILE, 'File not found')
        else:
            return path

    def open(self, path, pflags, attrs):
        """Open a file to serve to a remote client

           This method returns a file object which can be used to read
           and write data and get and set file attributes.

           The possible open mode flags and their meanings are:

             ========== ======================================================
             Mode       Description
             ========== ======================================================
             FXF_READ   Open the file for reading. If neither FXF_READ nor
                        FXF_WRITE are set, this is the default.
             FXF_WRITE  Open the file for writing. If both this and FXF_READ
                        are set, open the file for both reading and writing.
             FXF_APPEND Force writes to append data to the end of the file
                        regardless of seek position.
             FXF_CREAT  Create the file if it doesn't exist. Without this,
                        attempts to open a non-existent file will fail.
             FXF_TRUNC  Truncate the file to zero length if it already exists.
             FXF_EXCL   Return an error when trying to open a file which
                        already exists.
             ========== ======================================================

           The attrs argument is used to set initial attributes of the
           file if it needs to be created. Otherwise, this argument is
           ignored.

           :param path:
               The name of the file to open
           :param pflags:
               The access mode to use for the file (see above)
           :param attrs:
               File attributes to use if the file needs to be created
           :type path: `bytes`
           :type pflags: `int`
           :type attrs: :class:`SFTPAttrs`

           :returns: A file object to use to access the file

           :raises: :exc:`SFTPError` to return an error to the client

        """

        if pflags & FXF_EXCL:
            mode = 'xb'
        elif pflags & FXF_APPEND:
            mode = 'ab'
        elif pflags & FXF_WRITE and not pflags & FXF_READ:
            mode = 'wb'
        else:
            mode = 'rb'

        if pflags & FXF_READ and pflags & FXF_WRITE:
            mode += '+'
            flags = os.O_RDWR
        elif pflags & FXF_WRITE:
            flags = os.O_WRONLY
        else:
            flags = os.O_RDONLY

        if pflags & FXF_APPEND:
            flags |= os.O_APPEND

        if pflags & FXF_CREAT:
            flags |= os.O_CREAT

        if pflags & FXF_TRUNC:
            flags |= os.O_TRUNC

        if pflags & FXF_EXCL:
            flags |= os.O_EXCL

        flags |= getattr(os, 'O_BINARY', 0)

        perms = 0o666 if attrs.permissions is None else attrs.permissions
        return open(_to_local_path(self.map_path(path)), mode, buffering=0,
                    opener=lambda path, _: os.open(path, flags, perms))

    def close(self, file_obj):
        """Close an open file or directory

           :param file_obj:
               The file or directory object to close
           :type file_obj: file

           :raises: :exc:`SFTPError` to return an error to the client

        """

        file_obj.close()

    def read(self, file_obj, offset, size):
        """Read data from an open file

           :param file_obj:
               The file to read from
           :param offset:
               The offset from the beginning of the file to begin reading
           :param size:
               The number of bytes to read
           :type file_obj: file
           :type offset: `int`
           :type size: `int`

           :returns: bytes read from the file

           :raises: :exc:`SFTPError` to return an error to the client

        """

        file_obj.seek(offset)
        return file_obj.read(size)

    def write(self, file_obj, offset, data):
        """Write data to an open file

           :param file_obj:
               The file to write to
           :param offset:
               The offset from the beginning of the file to begin writing
           :param data:
               The data to write to the file
           :type file_obj: file
           :type offset: `int`
           :type data: `bytes`

           :returns: number of bytes written

           :raises: :exc:`SFTPError` to return an error to the client

        """

        file_obj.seek(offset)
        return file_obj.write(data)

    def lstat(self, path):
        """Get attributes of a file, directory, or symlink

           This method queries the attributes of a file, directory,
           or symlink. Unlike :meth:`stat`, this method should
           return the attributes of a symlink itself rather than
           the target of that link.

           :param path:
               The path of the file, directory, or link to get attributes for
           :type path: `bytes`

           :returns: An :class:`SFTPAttrs` or an os.stat_result containing
                     the file attributes

           :raises: :exc:`SFTPError` to return an error to the client

        """

        return os.lstat(_to_local_path(self.map_path(path)))

    def fstat(self, file_obj):
        """Get attributes of an open file

           :param file_obj:
               The file to get attributes for
           :type file_obj: file

           :returns: An :class:`SFTPAttrs` or an os.stat_result containing
                     the file attributes

           :raises: :exc:`SFTPError` to return an error to the client

        """

        file_obj.flush()
        return os.fstat(file_obj.fileno())

    def setstat(self, path, attrs):
        """Set attributes of a file or directory

           This method sets attributes of a file or directory. If
           the path provided is a symbolic link, the attributes
           should be set on the target of the link. A subset of the
           fields in `attrs` can be initialized and only those
           attributes should be changed.

           :param path:
               The path of the remote file or directory to set attributes for
           :param attrs:
               File attributes to set
           :type path: `bytes`
           :type attrs: :class:`SFTPAttrs`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        _setstat(_to_local_path(self.map_path(path)), attrs)

    def fsetstat(self, file_obj, attrs):
        """Set attributes of an open file

           :param file_obj:
               The file to set attributes for
           :param attrs:
               File attributes to set on the file
           :type file_obj: file
           :type attrs: :class:`SFTPAttrs`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        file_obj.flush()

        if sys.platform == 'win32': # pragma: no cover
            _setstat(file_obj.name, attrs)
        else:
            _setstat(file_obj.fileno(), attrs)

    def listdir(self, path):
        """List the contents of a directory

           :param path:
               The path of the directory to open
           :type path: `bytes`

           :returns: A list of names of files in the directory

           :raises: :exc:`SFTPError` to return an error to the client

        """

        files = os.listdir(_to_local_path(self.map_path(path)))

        if sys.platform == 'win32': # pragma: no cover
            files = [os.fsencode(f) for f in files]

        return [b'.', b'..'] + files

    def remove(self, path):
        """Remove a file or symbolic link

           :param path:
               The path of the file or link to remove
           :type path: `bytes`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        os.remove(_to_local_path(self.map_path(path)))

    def mkdir(self, path, attrs):
        """Create a directory with the specified attributes

           :param path:
               The path of where the new directory should be created
           :param attrs:
               The file attributes to use when creating the directory
           :type path: `bytes`
           :type attrs: :class:`SFTPAttrs`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        mode = 0o777 if attrs.permissions is None else attrs.permissions
        os.mkdir(_to_local_path(self.map_path(path)), mode)

    def rmdir(self, path):
        """Remove a directory

           :param path:
               The path of the directory to remove
           :type path: `bytes`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        os.rmdir(_to_local_path(self.map_path(path)))

    def realpath(self, path):
        """Return the canonical version of a path

           :param path:
               The path of the directory to canonicalize
           :type path: `bytes`

           :returns: bytes containing the canonical path

           :raises: :exc:`SFTPError` to return an error to the client

        """

        path = os.path.realpath(_to_local_path(self.map_path(path)))
        return self.reverse_map_path(_from_local_path(path))

    def stat(self, path):
        """Get attributes of a file or directory, following symlinks

           This method queries the attributes of a file or directory.
           If the path provided is a symbolic link, the returned
           attributes should correspond to the target of the link.

           :param path:
               The path of the remote file or directory to get attributes for
           :type path: `bytes`

           :returns: An :class:`SFTPAttrs` or an os.stat_result containing
                     the file attributes

           :raises: :exc:`SFTPError` to return an error to the client

        """

        return os.stat(_to_local_path(self.map_path(path)))

    def rename(self, oldpath, newpath):
        """Rename a file, directory, or link

           This method renames a file, directory, or link.

           .. note:: This is a request for the standard SFTP version
                     of rename which will not overwrite the new path
                     if it already exists. The :meth:`posix_rename`
                     method will be called if the client requests the
                     POSIX behavior where an existing instance of the
                     new path is removed before the rename.

           :param oldpath:
               The path of the file, directory, or link to rename
           :param newpath:
               The new name for this file, directory, or link
           :type oldpath: `bytes`
           :type newpath: `bytes`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        oldpath = _to_local_path(self.map_path(oldpath))
        newpath = _to_local_path(self.map_path(newpath))

        if os.path.exists(newpath):
            raise SFTPError(FX_FAILURE, 'File already exists')

        os.rename(oldpath, newpath)

    def readlink(self, path):
        """Return the target of a symbolic link

           :param path:
               The path of the symbolic link to follow
           :type path: `bytes`

           :returns: bytes containing the target path of the link

           :raises: :exc:`SFTPError` to return an error to the client

        """

        path = os.readlink(_to_local_path(self.map_path(path)))
        return self.reverse_map_path(_from_local_path(path))

    def symlink(self, oldpath, newpath):
        """Create a symbolic link

           :param oldpath:
               The path the link should point to
           :param newpath:
               The path of where to create the symbolic link
           :type oldpath: `bytes`
           :type newpath: `bytes`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        if posixpath.isabs(oldpath):
            oldpath = self.map_path(oldpath)
        else:
            newdir = posixpath.dirname(newpath)
            abspath1 = self.map_path(posixpath.join(newdir, oldpath))

            mapped_newdir = self.map_path(newdir)
            abspath2 = os.path.join(mapped_newdir, oldpath)

            # Make sure the symlink doesn't point outside the chroot
            if os.path.realpath(abspath1) != os.path.realpath(abspath2):
                oldpath = os.path.relpath(abspath1, start=mapped_newdir)

        newpath = self.map_path(newpath)

        os.symlink(_to_local_path(oldpath), _to_local_path(newpath))

    def posix_rename(self, oldpath, newpath):
        """Rename a file, directory, or link with POSIX semantics

           This method renames a file, directory, or link, removing
           the prior instance of new path if it previously existed.

           :param oldpath:
               The path of the file, directory, or link to rename
           :param newpath:
               The new name for this file, directory, or link
           :type oldpath: `bytes`
           :type newpath: `bytes`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        oldpath = _to_local_path(self.map_path(oldpath))
        newpath = _to_local_path(self.map_path(newpath))

        os.replace(oldpath, newpath)

    def statvfs(self, path):
        """Get attributes of the file system containing a file

           :param path:
               The path of the file system to get attributes for
           :type path: `bytes`

           :returns: An :class:`SFTPVFSAttrs` or an os.statvfs_result
                     containing the file system attributes

           :raises: :exc:`SFTPError` to return an error to the client

        """

        try:
            return os.statvfs(_to_local_path(self.map_path(path)))
        except AttributeError: # pragma: no cover
            raise SFTPError(FX_OP_UNSUPPORTED, 'statvfs not supported')

    def fstatvfs(self, file_obj):
        """Return attributes of the file system containing an open file

           :param file_obj:
               The open file to get file system attributes for
           :type file_obj: file

           :returns: An :class:`SFTPVFSAttrs` or an os.statvfs_result
                     containing the file system attributes

           :raises: :exc:`SFTPError` to return an error to the client

        """

        try:
            return os.statvfs(file_obj.fileno())
        except AttributeError: # pragma: no cover
            raise SFTPError(FX_OP_UNSUPPORTED, 'fstatvfs not supported')

    def link(self, oldpath, newpath):
        """Create a hard link

           :param oldpath:
               The path of the file the hard link should point to
           :param newpath:
               The path of where to create the hard link
           :type oldpath: `bytes`
           :type newpath: `bytes`

           :raises: :exc:`SFTPError` to return an error to the client

        """

        oldpath = _to_local_path(self.map_path(oldpath))
        newpath = _to_local_path(self.map_path(newpath))

        os.link(oldpath, newpath)

    def fsync(self, file_obj):
        """Force file data to be written to disk

           :param file_obj:
               The open file containing the data to flush to disk
           :type file_obj: file

           :raises: :exc:`SFTPError` to return an error to the client

        """

        os.fsync(file_obj.fileno())

    def exit(self):
        """Shut down this SFTP server"""

        pass


class SFTPServerFile:
    """A wrapper around SFTPServer used to access files it manages"""

    def __init__(self, server):
        self._server = server
        self._file_obj = None

    @asyncio.coroutine
    def stat(self, path):
        """Get attributes of a file"""

        attrs = self._server.stat(path)

        if asyncio.iscoroutine(attrs):
            attrs = yield from attrs

        if isinstance(attrs, os.stat_result):
            attrs = SFTPAttrs.from_local(attrs)

        return attrs

    @asyncio.coroutine
    def setstat(self, path, attrs):
        """Set attributes of a file or directory"""

        result = self._server.setstat(path, attrs)

        if asyncio.iscoroutine(result):
            attrs = yield from result

    @asyncio.coroutine
    def _mode(self, path):
        """Return the file mode of a path, or 0 if it can't be accessed"""

        try:
            return (yield from self.stat(path)).permissions
        except OSError as exc:
            if exc.errno in (errno.ENOENT, errno.EACCES):
                return 0
            else:
                raise
        except SFTPError as exc:
            if exc.code in (FX_NO_SUCH_FILE, FX_PERMISSION_DENIED):
                return 0
            else:
                raise

    @asyncio.coroutine
    def exists(self, path):
        """Return if a path exists"""

        return (yield from self._mode(path)) != 0

    @asyncio.coroutine
    def isdir(self, path):
        """Return if the path refers to a directory"""

        return stat.S_ISDIR((yield from self._mode(path)))

    @asyncio.coroutine
    def mkdir(self, path):
        """Create a directory"""

        result = self._server.mkdir(path, SFTPAttrs())

        if asyncio.iscoroutine(result):
            yield from result

    @asyncio.coroutine
    def listdir(self, path):
        """List the contents of a directory"""

        files = self._server.listdir(path)

        if asyncio.iscoroutine(files):
            files = yield from files

        return files

    @asyncio.coroutine
    def open(self, path, mode='rb'):
        """Open a file"""

        pflags, _ = _mode_to_pflags(mode)
        file_obj = self._server.open(path, pflags, SFTPAttrs())

        if asyncio.iscoroutine(file_obj):
            file_obj = yield from file_obj

        self._file_obj = file_obj
        return self

    @asyncio.coroutine
    def read(self, size, offset):
        """Read bytes from the file"""

        data = self._server.read(self._file_obj, offset, size)

        if asyncio.iscoroutine(data):
            data = yield from data

        return data

    @asyncio.coroutine
    def write(self, data, offset):
        """Write bytes to the file"""

        size = self._server.write(self._file_obj, offset, data)

        if asyncio.iscoroutine(size):
            size = yield from size

        return size

    @asyncio.coroutine
    def close(self):
        """Close a file managed by the associated SFTPServer"""

        result = self._server.close(self._file_obj)

        if asyncio.iscoroutine(result):
            yield from result


@asyncio.coroutine
def start_sftp_client(conn, loop, reader, writer, path_encoding, path_errors):
    """Start an SFTP client"""

    handler = SFTPClientHandler(loop, reader, writer)

    handler.logger.info('Starting SFTP client')

    yield from handler.start()

    conn.create_task(handler.recv_packets(), handler.logger)

    return SFTPClient(loop, handler, path_encoding, path_errors)


@asyncio.coroutine
def run_sftp_server(sftp_server, reader, writer):
    """Return a handler for an SFTP server session"""

    handler = SFTPServerHandler(sftp_server, reader, writer)

    handler.logger.info('Starting SFTP server')

    yield from handler.run()
