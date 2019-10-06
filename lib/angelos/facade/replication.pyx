# cython: language_level=3
"""

Copyright (c) 2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade replication API."""
import uuid
import math

from ..replication.preset import (
    Preset,
    MailClientPreset,
    MailServerPreset,
    CustomPreset,
    FileSyncInfo,
)
from ..replication.handler import Actions, CHUNK_SIZE
from ..archive.helper import Globber


class ReplicationAPI:
    def __init__(self, facade):
        self._facade = facade

    def create_preset(
        self, name: str, ptype: int, userid: uuid.UUID, **kwargs
    ):
        if name == Preset.T_CUSTOM:
            return CustomPreset(
                kwargs["archive"],
                name,
                kwargs["modified"],
                kwargs["path"],
                kwargs["owner"],
            )
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
            archive.archive,
            preset.path,
            preset.owner if preset.owner.int else None,
            preset.modified,
            True,
        )

    def save_file(
            self, preset: Preset, fileinfo: FileSyncInfo, action: str) -> bool:
        """Create or update file in archive."""
        archive = self._facade.archive(preset.archive)
        full_path = preset.to_absolute(fileinfo.path)

        if action == Actions.CLI_CREATE:
            return archive.archive.mkfile(
                full_path,
                fileinfo.data,
                created=fileinfo.created,
                modified=fileinfo.modified,
                owner=fileinfo.owner,
                id=fileinfo.fileid,
                user=fileinfo.user,
                group=fileinfo.group,
                perms=fileinfo.perms,
            )
        elif action == Actions.CLI_UPDATE:
            archive.archive.save(
                full_path, fileinfo.data, modified=fileinfo.modified
            )
            archive.archive.chmod(
                full_path,
                id=fileinfo.fileid,
                owner=fileinfo.owner,
                created=fileinfo.created,
                user=fileinfo.user,
                group=fileinfo.group,
                perms=fileinfo.perms,
            )
            return True

    def load_file(self, preset: Preset, fileinfo: FileSyncInfo) -> bool:
        """Load file and meta from archive."""
        archive = self._facade.archive(preset.archive)
        full_path = preset.to_absolute(fileinfo.path)

        entry = archive.archive.info(full_path)

        fileinfo.pieces = int(math.ceil(entry.length / CHUNK_SIZE))
        fileinfo.size = entry.length
        fileinfo.digest = entry.digest

        fileinfo.filename = entry.name
        fileinfo.created = entry.created
        fileinfo.modified = entry.modified
        fileinfo.owner = entry.owner
        fileinfo.fileid = entry.id
        fileinfo.user = entry.user
        fileinfo.group = entry.group
        fileinfo.perms = entry.perms

        fileinfo.data = archive.archive.load(full_path)
        return True

    def del_file(self, preset: Preset, fileinfo: FileSyncInfo) -> bool:
        """Remove file from archive"""
        archive = self._facade.archive(preset.archive)
        full_path = preset.to_absolute(fileinfo.path)
        return archive.archive.remove(full_path)
