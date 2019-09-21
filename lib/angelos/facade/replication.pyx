# cython: language_level=3
"""

Copyright (c) 2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade replication API."""
import uuid

from ..replication.preset import (
    Preset, MailClientPreset, MailServerPreset, CustomPreset)
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
