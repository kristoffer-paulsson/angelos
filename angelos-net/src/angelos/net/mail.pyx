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
"""Authentication handler."""
from angelos.net.base import Handler, ProtocolSession, Packet, DataType
import uuid
import asyncio

SESH_TYPE_RECEIVE = 0x01
SESH_TYPE_SEND = 0x02
SESH_TYPE_DOWNLOAD = 0x03
SESH_TYPE_UPLOAD = 0x04

ST_FILE_ID = 0x01
ST_BLOCK_CNT = 0x02


class MailError(RuntimeError):
    """Unrepairable errors in the mail handler."""
    INIT_FAILED = ("Initialization if protocol failed", 100)


class CollectPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Request to collect a mail from server."""


class DispatchNotePacket(Packet, fields=tuple(), fields_info=tuple()):
    """Response to mail collect request."""


class ReceiveSession(ProtocolSession):
    def __init__(self, server: bool):
        ProtocolSession.__init__(self, SESH_TYPE_RECEIVE, dict(), server)


class SendSession(ProtocolSession):
    def __init__(self, server: bool):
        ProtocolSession.__init__(self, SESH_TYPE_SEND, dict(), server)


class DownloadSession(ProtocolSession):
    def __init__(self, server: bool, file_id: uuid.UUID, blk_cnt: int = 0):
        ProtocolSession.__init__(self, SESH_TYPE_DOWNLOAD, {
            ST_FILE_ID: file_id.bytes,
            ST_BLOCK_CNT: hex(blk_cnt)[2:].encode()
        }, server)


class UploadSession(ProtocolSession):
    def __init__(self, server: bool, file_id: uuid.UUID = uuid.UUID(int=0), blk_cnt: int = 0):
        ProtocolSession.__init__(self, SESH_TYPE_UPLOAD, {
            ST_FILE_ID: file_id.bytes,
            ST_BLOCK_CNT: hex(blk_cnt)[2:].encode()
        }, server)


class MailHandler(Handler):
    """Base handler for mail."""

    LEVEL = 1
    RANGE = 1

    SESH_RECEIVE = SESH_TYPE_RECEIVE
    SESH_SEND = SESH_TYPE_SEND
    SESH_DOWNLOAD = SESH_TYPE_DOWNLOAD
    SESH_UPLOAD = SESH_TYPE_UPLOAD

    ST_VERSION = 0x01
    ST_USER = 0x02

    def __init__(self, manager: "Protocol"):
        super().__init__(manager, {
            self.ST_VERSION: b"mail-0.1",
            self.ST_USER: b""
        }, {
            self.SESH_SEND: SendSession,
            self.SESH_RECEIVE: ReceiveSession,
            self.SESH_UPLOAD: UploadSession,
            self.SESH_DOWNLOAD: DownloadSession
        }, 8)


class MailClient(MailHandler):
    """Client side mail handler."""

    async def start(self, user: uuid.UUID) -> bool:
        """Make authentication against server."""
        self._states[self.ST_USER] = user.bytes

        init = await self.sync(tuple(self._states.keys()))
        if not init:
            raise MailError(*MailError.INIT_FAILED)

        async with self.context(self.SESH_RECEIVE) as sesh_receive:
            await asyncio.sleep(0)

        async with self.context(self.SESH_SEND) as sesh_send:
            await asyncio.sleep(0)


class MailServer(MailHandler):
    """Server side mail handler."""