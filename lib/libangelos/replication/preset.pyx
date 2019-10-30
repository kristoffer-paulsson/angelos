# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""
Replication presets. The presets defines specific replication behavior needed
for several purposes.
"""
import uuid
import datetime
import pathlib

from ..const import Const
from ..facade.mail import MailAPI
from ..ioc import Container
from ..policy.portfolio import Portfolio


class FileSyncInfo:
    def __init__(self):
        self.fileid = uuid.UUID(int=0)
        self.path = ""
        self.deleted = None
        self.pieces = 0
        self.size = 0
        self.digest = b""
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
        self,
        archive: str,
        preset: str = "custom",
        modified: datetime.datetime = None,
        path: str = "/",
        owner: uuid.UUID = None,
    ):
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

        fileinfo = FileSyncInfo()
        fileinfo.fileid = fileid
        fileinfo.path = meta[0]
        fileinfo.modified = meta[1]
        fileinfo.deleted = meta[2]
        return fileinfo

    def get_file_meta(self, keys: uuid.UUID) -> FileSyncInfo:
        """Pop meta information off."""
        if keys in list(self.files.keys()):
            meta = self.files[keys]
        else:
            return FileSyncInfo()

        del self.files[keys]

        fileinfo = FileSyncInfo()
        fileinfo.fileid = keys
        fileinfo.path = meta[0]
        fileinfo.modified = meta[1]
        fileinfo.deleted = meta[2]
        return fileinfo

    def file_processed(self, fileid: uuid.UUID):
        self.processed.add(fileid)

    def to_relative(self, path: str) -> str:
        """Convert absolute path to relative."""
        return str(pathlib.PurePath(path).relative_to(self.path))

    def to_absolute(self, path: str) -> str:
        """Convert relative path to absolute."""
        return str(pathlib.PurePath(self.path).joinpath(path))

    def on_init(self, ioc: Container, portfolio: Portfolio=None):
        """Execute event before init."""
        pass

    def on_close(
            self, ioc: Container, portfolio: Portfolio=None,
            crash: bool=False):
        """Execute event after close."""
        pass

    def on_before_pull(
            self, ioc: Container, portfolio: Portfolio=None,
            crash: bool=False):
        """Execute event before pull."""
        pass

    def on_after_pull(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after pull."""
        pass

    def on_before_push(
            self, ioc: Container, portfolio: Portfolio=None,
            crash: bool=False):
        """Execute event before push."""
        pass

    def on_after_push(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after push."""
        pass

    def on_before_upload(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event before upload."""
        pass

    def on_after_upload(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after upload."""
        pass

    def on_before_download(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event before download."""
        pass

    def on_after_download(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after download."""
        pass

    def on_before_delete(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event before delete."""
        pass

    def on_after_delete(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Execute event after delete."""
        pass


class CustomPreset(Preset):
    pass


class MailClientPreset(Preset):
    def __init__(self, modified: datetime.datetime = None):
        Preset.__init__(
            self, Const.CNL_VAULT, Preset.T_MAIL, modified, MailAPI.OUTBOX
        )

    def to_absolute(self, path: str) -> str:
        """Convert relative path to absolute."""
        return str(pathlib.PurePath(MailAPI.INBOX).joinpath(path))

    def on_after_upload(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Remove sent and uploaded envelopes."""
        if not crash:
            ioc.facade.replication.del_file(self, clientfile)


class MailServerPreset(Preset):
    def __init__(
        self, modified: datetime.datetime = None, owner: uuid.UUID = None
    ):
        Preset.__init__(
            self, Const.CNL_MAIL, Preset.T_MAIL, modified, "/", owner=owner
        )

    def on_after_download(
            self, serverfile: FileSyncInfo, clientfile: FileSyncInfo,
            ioc: Container, portfolio: Portfolio=None, crash: bool=False):
        """Remove received and downloaded envelopes."""
        if not crash:
            ioc.facade.replication.del_file(self, serverfile)
