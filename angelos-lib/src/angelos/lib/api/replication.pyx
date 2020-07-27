# cython: language_level=3
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
"""Facade replication API."""
import math
import uuid

from angelos.lib.api.api import ApiFacadeExtension
from angelos.lib.facade.base import BaseFacade
from angelos.lib.helper import Globber
from angelos.lib.replication.handler import Actions, CHUNK_SIZE
from angelos.lib.replication.preset import Preset, MailClientPreset, MailServerPreset, CustomPreset, FileSyncInfo


class ReplicationAPI(ApiFacadeExtension):
    """
    API for the replication protocol to interact through.
    """

    ATTRIBUTE = ("replication",)

    def __init__(self, facade: BaseFacade):
        ApiFacadeExtension.__init__(self, facade)

    def create_preset(
            self, name: str, p_type: int, user_id: uuid.UUID, **kwargs
    ):
        """
        Create a preset based on input data.

        :param name:
        :param p_type:
        :param user_id:
        :param kwargs:
        :return:
        """
        if name == Preset.T_CUSTOM:
            return CustomPreset(
                kwargs["archive"],
                name,
                kwargs["modified"],
                kwargs["path"],
                kwargs["owner"],
            )
        elif name == Preset.T_MAIL:
            if p_type == Preset.CLIENT:
                return MailClientPreset()
            elif p_type == Preset.SERVER:
                return MailServerPreset(owner=user_id)

    async def load_files_list(self, preset: Preset):
        """Index and load the list of files to be replicated.

        preset.files[name] = (entry.id, entry.deleted, entry.modified)
        """
        storage = getattr(self.facade.storage, preset.archive)
        preset._files = await Globber.syncro(
            storage.archive,
            preset.path,
            preset.owner if preset.owner.int else None,
            preset.modified,
            True
        )

    async def save_file(
            self, preset: Preset, file_info: FileSyncInfo, action: str) -> bool:
        """Create or update file in archive."""
        storage = getattr(self.facade.storage, preset.archive)
        full_path = preset.to_absolute(file_info.path)

        if action in (Actions.CLI_CREATE, Actions.SER_CREATE):
            return await storage.archive.mkfile(
                full_path,
                file_info.data,
                created=file_info.created,
                modified=file_info.modified,
                owner=file_info.owner,
                id=file_info.fileid,
                user=file_info.user,
                group=file_info.group,
                perms=file_info.perms,
            )
        elif action in (Actions.CLI_UPDATE, Actions.SER_UPDATE):
            await storage.archive.save(
                full_path, file_info.data, modified=file_info.modified
            )
            await storage.archive.chmod(
                full_path,
                id=file_info.fileid,
                owner=file_info.owner,
                created=file_info.created,
                user=file_info.user,
                group=file_info.group,
                perms=file_info.perms,
            )
            return True
        else:
            raise Exception("Illegal action for save_file")

    async def load_file(self, preset: Preset, file_info: FileSyncInfo) -> bool:
        """Load file and meta from archive."""
        storage = getattr(self.facade.storage, preset.archive)
        full_path = preset.to_absolute(file_info.path)

        entry = await storage.archive.info(full_path)

        file_info.pieces = int(math.ceil(entry.length / CHUNK_SIZE))
        file_info.size = entry.length

        file_info.filename = entry.name
        file_info.created = entry.created
        file_info.modified = entry.modified
        file_info.owner = entry.owner
        file_info.fileid = entry.id
        file_info.user = entry.user if entry.user else file_info.user
        file_info.group = entry.group if entry.group else file_info.group
        file_info.perms = entry.perms if entry.perms else file_info.perms

        file_info.data = await storage.archive.load(full_path)

        return True

    async def del_file(self, preset: Preset, file_info: FileSyncInfo) -> bool:
        """Remove file from archive"""
        storage = getattr(self.facade.storage, preset.archive)
        full_path = preset.to_absolute(file_info.path)
        return await storage.archive.remove(full_path)
