# cython: language_level=3
"""

Copyright (c) 2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade replication API."""
import uuid

from ..replication.preset import (
    Preset, MailClientPreset, MailServerPreset, CustomPreset, FileSyncInfo)
from ..replication.handler import Actions
from ..archive.helper import Globber


class ReplicationAPI:
    def __init__(self, facade):
        self._facade = facade

    def create_preset(
            self, name: str, ptype: int, userid: uuid.UUID, **kwargs):
        if name == Preset.T_CUSTOM:
            return CustomPreset(
                kwargs['archive'], name,
                kwargs['modified'], kwargs['path'],
                kwargs['owner'])
        elif name == Preset.T_MAIL:
            if ptype == Preset.CLIENT:
                return MailClientPreset()
            elif ptype == Preset.SERVER:
                return MailServerPreset(owner=userid)

    def load_files_list(self, preset: Preset):
        """Index and load the list of files to be replicated.

        preset.files[name] = (entry.id, entry.deleted, entry.modified)
        """
        archive = self._facade.archive(preset.archive)
        preset._files = Globber.syncro(
            archive.archive, preset.path,
            preset.owner if preset.owner.int else None,
            preset.modified, True)

    def save_file(self, preset: Preset, fileinfo: FileSyncInfo) -> bool:
        """Create or update file in archive."""
        archive = self._facade.archive(preset.archive)
        full_path = preset.to_absolute(fileinfo.path)

        if self._fileinfo.action == Actions.CLI_CREATE:
            return archive.archive.mkfile(
                full_path, fileinfo.data, created=fileinfo.created,
                modified=fileinfo.modified, owner=fileinfo.owner,
                id=fileinfo.fileid, user=fileinfo.user, group=fileinfo.group,
                perms=fileinfo.perms)
        elif self._fineinfo.action == Actions.CLI_UPDATE:
            archive.archive.save(
                full_path, fileinfo.data,  modified=fileinfo.modified)
            archive.archive.chmod(
                full_path, id=fileinfo.fileid, owner=fileinfo.owner,
                created=fileinfo.created, user=fileinfo.user,
                group=fileinfo.group, perms=fileinfo.perms)
            return True

    def load_file(self, preset: Preset, fileinfo: FileSyncInfo) -> bool:
        """Load file from archive."""
        archive = self._facade.archive(preset.archive)
        full_path = preset.to_absolute(fileinfo.path)

        if self._fileinfo.action == Actions.CLI_CREATE:
            return archive.archive.mkfile(
                full_path, fileinfo.data, created=fileinfo.created,
                modified=fileinfo.modified, owner=fileinfo.owner,
                id=fileinfo.fileid, user=fileinfo.user, group=fileinfo.group,
                perms=fileinfo.perms)
        elif self._fineinfo.action == Actions.CLI_UPDATE:
            archive.archive.save(
                full_path, fileinfo.data,  modified=fileinfo.modified)
            archive.archive.chmod(
                full_path, id=fileinfo.fileid, owner=fileinfo.owner,
                created=fileinfo.created, user=fileinfo.user,
                group=fileinfo.group, perms=fileinfo.perms)
            return True
