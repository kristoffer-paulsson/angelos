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
"""
Replication presets. The presets defines specific replication behavior needed
for several purposes.
"""
import datetime
from pathlib import PurePosixPath
import uuid

from angelos.facade.api.mailbox import MailboxAPI
from angelos.facade.storage.mail import MailStorage
from angelos.facade.storage.vault import VaultStorage
from angelos.lib.ioc import Container
from angelos.portfolio.collection import Portfolio


class FileSyncInfo:
    def __init__(self):
        self.fileid = uuid.UUID(int=0)
        self.path = ""  # PurePosixPath("/")
        self.deleted = None
        self.pieces = 0
        self.size = 0
        self.filename = ""
        self.created = datetime.datetime(1, 1, 1)
        self.modified = datetime.datetime(1, 1, 1)
        self.owner = uuid.UUID(int=0)
        self.user = ""
        self.group = ""
        self.perms = 0x0
        self.data = b""


class Preset:
    """Preset operation.

    Holds the current status for an ongoing replication operation."""

    CLIENT = 0
    SERVER = 1

    T_CUSTOM = "custom"
    T_MAIL = "mail"

    def __init__(
            self, archive: str, preset: str = "custom", modified: datetime.datetime = None,
            path: PurePosixPath = PurePosixPath("/"), owner: uuid.UUID = None):
        """Preset operation."""
        self._preset = preset
        self._modified = modified if modified else datetime.datetime(1, 1, 1)
        self._path = path
        self._owner = owner if owner else uuid.UUID(int=0)
        self._archive = archive

        self._files = {}
        self._processed = set()

    @property
    def preset(self):
        """Name of the preset."""
        return self._preset

    @property
    def modified(self):
        """Last modified datetime to synchronize."""
        return self._modified

    @property
    def path(self):
        """Path to synchronize."""
        return self._path

    @property
    def owner(self):
        """Owner UUID to synchronize."""
        return self._owner

    @property
    def archive(self):
        """The archive to synchronize."""
        return self._archive

    @property
    def files(self):
        """The list of files being replicated."""
        return self._files

    @property
    def processed(self):
        """Already replicated files ID:s."""
        return self._processed

    def pull_file_meta(self) -> FileSyncInfo:
        """Pop meta information off."""
        keys = list(self.files.keys())
        if keys:
            fileid = keys.pop()
        else:
            return FileSyncInfo()
        meta = self.files[fileid]
        del self.files[fileid]

        file_info = FileSyncInfo()
        file_info.fileid = fileid
        file_info.path = PurePosixPath(meta[0])
        file_info.modified = meta[1]
        file_info.deleted = meta[2]
        return file_info

    def get_file_meta(self, keys: uuid.UUID) -> FileSyncInfo:
        """Pop meta information off."""
        if keys in list(self.files.keys()):
            meta = self.files[keys]
        else:
            return FileSyncInfo()

        del self.files[keys]

        file_info = FileSyncInfo()
        file_info.fileid = keys
        file_info.path = PurePosixPath(meta[0])
        file_info.modified = meta[1]
        file_info.deleted = meta[2]
        return file_info

    def file_processed(self, fileid: uuid.UUID):
        self.processed.add(fileid)

    def to_relative(self, path: PurePosixPath) -> PurePosixPath:
        """Convert absolute path to relative."""
        print("TO_RELATIVE", path, self.path, PurePosixPath(path).relative_to(self.path))
        # try:
        #    return self.path.relative_to(path)
        #except ValueError:
        return PurePosixPath(path).relative_to(self.path)

    def to_absolute(self, path: PurePosixPath) -> PurePosixPath:
        """Convert relative path to absolute."""
        return self.path.joinpath(path)

    async def on_init(self, ioc: Container, portfolio: Portfolio=None):
        """Execute event before init."""
        pass

    async def on_close(
            self, ioc: Container, portfolio: Portfolio=None,
            crash: bool=False):
        """Execute event after close."""
        pass

    async def on_before_pull(
            self, ioc: Container, portfolio: Portfolio=None,
            crash: bool=False):
        """Execute event before pull."""
        pass

    async def on_after_pull(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after pull."""
        pass

    async def on_before_push(
            self, ioc: Container, portfolio: Portfolio=None,
            crash: bool=False):
        """Execute event before push."""
        pass

    async def on_after_push(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after push."""
        pass

    async def on_before_upload(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event before upload."""
        pass

    async def on_after_upload(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after upload."""
        pass

    async def on_before_download(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event before download."""
        pass

    async def on_after_download(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after download."""
        pass

    async def on_before_delete(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event before delete."""
        pass

    async def on_after_delete(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after delete."""
        pass


class CustomPreset(Preset):
    pass


class MailClientPreset(Preset):
    def __init__(self, modified: datetime.datetime = None):
        Preset.__init__(
            self, VaultStorage.ATTRIBUTE[0], Preset.T_MAIL,
            modified, MailboxAPI.PATH_OUTBOX[0])

    def to_absolute(self, path: PurePosixPath) -> PurePosixPath:
        """Convert relative path to absolute."""
        return MailboxAPI.PATH_INBOX[0].joinpath(path)

    async def on_after_upload(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Remove sent and uploaded envelopes."""
        if not crash:
            await ioc.facade.api.replication.del_file(self, clientfile)


class MailServerPreset(Preset):
    def __init__(self, modified: datetime.datetime = None, owner: uuid.UUID = None):
        Preset.__init__(
            self, MailStorage.ATTRIBUTE[0], Preset.T_MAIL,
            modified, PurePosixPath("/"), owner=owner)

    async def on_after_download(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Remove received and downloaded envelopes."""
        if not crash:
            await ioc.facade.api.replication.del_file(self, serverfile)
