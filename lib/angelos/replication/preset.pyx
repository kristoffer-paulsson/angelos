# cython: language_level=3
"""

Copyright (c) 2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Replication presets. The presets defines specific replication behavior needed
for several purposes.
"""
import uuid
import datetime
import pathlib
from typing import Tuple

from ..const import Const
from ..facade.mail import MailAPI


class Preset:
    """Preset operation.

    Holds the current status for an ongoing replication operation."""
    CLIENT = 0
    SERVER = 1

    T_CUSTOM = 'custom'
    T_MAIL = 'mail'

    def __init__(
            self, archive: str,
            preset: str='custom',
            modified: datetime.datetime=None,
            path: str='/',
            owner: uuid.UUID=None
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

    def pull_file_meta(self) -> Tuple[str, uuid.UUID, datetime.datetime, bool]:
        """Pop meta information off."""
        keys = list(self.files.keys())
        if keys:
            fileid = keys.pop()
        else:
            return (None, None, None, None)
        meta = self.files[fileid]
        del self.files[fileid]
        return (fileid, ) + meta

    def file_processed(self, fileid: uuid.UUID):
        self.processed.add(fileid)

    def to_relative(self, path: str) -> str:
        """Convert absolute path to relative."""
        return str(pathlib.PurePath(path).relative_to(self.path))

    def to_absolute(self, path: str) -> str:
        """Convert relative path to absolute."""
        return str(pathlib.PurePath(self.path).joinpath(path))


class CustomPreset(Preset):
    pass


class MailClientPreset(Preset):
    def __init__(self, modified: datetime.datetime=None):
        Preset.__init__(
            self, Const.CNL_VAULT, Preset.T_MAIL,
            modified, MailAPI.OUTBOX)

    def to_absolute(self, path: str) -> str:
        """Convert relative path to absolute."""
        return str(pathlib.PurePath(MailAPI.INBOX).joinpath(path))


class MailServerPreset(Preset):
    def __init__(
            self, modified: datetime.datetime=None, owner: uuid.UUID=None):
        Preset.__init__(
            self, Const.CNL_MAIL, Preset.T_MAIL, modified, '/', owner=owner)
