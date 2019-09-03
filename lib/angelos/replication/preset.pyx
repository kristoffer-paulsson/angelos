# cython: language_level=3
"""

Copyright (c) 2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Replication presets. The presets defines specific replication behavior needed
for several purposes.
"""
import uuid

from ..const import Const


class BasePreset:
    def __init__(self):
        self._importing = False

    @property
    def client(self):
        return self._CLIENT

    @property
    def server(self):
        return self._SERVER

    @property
    def importing(self):
        return self._importing


class CustomPreset:
    PRESET = 'custom'
    _CLIENT = {}
    _SERVER = {}

    def __init__(
            self, archive: str=Const.CNL_VAULT,
            path: str='/', owner: uuid.UUID=uuid.UUID(int=0)):
        BasePreset.__init__(self)
        P = {
            'ARCHIVE': archive,
            'PATH': path,
            'OWNER': owner
        }

        self._CLIENT = P
        self._SERVER = P


class MailPreset(BasePreset):
    PRESET = 'mail'
    _CLIENT = {
        'ARCHIVE': Const.CNL_VAULT,
        'PATH': '/messages/outbox',
        'OWNER': ''
    }
    _SERVER = {
        'ARCHIVE': Const.CNL_MAIL,
        'PATH': '/',
        'OWNER': ''
    }

    def __init__(self, owner: uuid.UUID):
        BasePreset.__init__(self)
        self._importing = True
        self._CLIENT['OWNER'] = owner
        self._SERVER['OWNER'] = owner
