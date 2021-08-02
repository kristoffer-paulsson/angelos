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
"""Multiplatform file lock mechanism to ensure file is only open by one process."""
import os
from abc import ABC, abstractmethod


class BaseFileLock(ABC):
    """Lock/unlock file on disk."""

    @classmethod
    @abstractmethod
    def acquire(cls, fd):
        """Acquire file lock."""

    @classmethod
    @abstractmethod
    def release(cls, fd):
        """Release file lock."""


if os.name == "posix":

    import fcntl


    class FileLock(BaseFileLock):
        """File lock implementation for posix."""

        @classmethod
        def acquire(cls, fd):
            fcntl.lockf(fd.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)

        @classmethod
        def release(cls, fd):
            fcntl.lockf(fd.fileno(), fcntl.LOCK_UN)

elif os.name == "nt":

    import win32file
    import pywintypes
    import win32con


    class FileLock(BaseFileLock):
        """File lock implementation for windows."""

        @classmethod
        def acquire(cls, fd):
            handle = win32file._get_osfhandle(fd.fileno())
            win32file.LockFileEx(
                handle,
                win32con.LOCKFILE_EXCLUSIVE_LOCK | win32con.LOCKFILE_FAIL_IMMEDIATELY,
                0, -0x10000, pywintypes.OVERLAPPED()
            )

        @classmethod
        def release(cls, fd):
            handle = win32file._get_osfhandle(fd.fileno())
            win32file.UnlockFileEx(handle, 0, -0x10000, pywintypes.OVERLAPPED())

else:

    class FileLock(BaseFileLock):
        """Dummy file lock without implementation."""

        dummy = True

        @classmethod
        def acquire(cls, fd):
            raise NotImplementedError("Not implemented for platform: {}".format(os.name))

        @classmethod
        def release(cls, fd):
            raise NotImplementedError("Not implemented for platform: {}".format(os.name))
