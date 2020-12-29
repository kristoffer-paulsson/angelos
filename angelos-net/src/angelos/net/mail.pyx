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
"""Mail handler."""
import asyncio
import hashlib
import uuid
from pathlib import PurePosixPath

from angelos.net.base import Handler, ProtocolSession, Packet, DataType, WaypointState, DonePacket
from angelos.portfolio.collection import Portfolio

SESH_TYPE_RECEIVE = 0x01
SESH_TYPE_SEND = 0x02
SESH_TYPE_DOWNLOAD = 0x03
SESH_TYPE_UPLOAD = 0x04

ST_FILE_ID = 0x01
ST_BLOCK_CNT = 0x02

ST_COLLECTOR = 0x01

COLLECT_PACKET = 0x01
DISPATCH_NOTE_PACKET = 0x02
PULL_PACKET = 0x03
BLOCK_PACKET = 0x04


class BlockError(RuntimeWarning):
    """Block data digest mismatch."""
pass


class MailError(RuntimeError):
    """Unrepairable errors in the mail handler."""
    INIT_FAILED = ("Initialization if protocol failed", 100)
    FD_ALREADY_OPEN = ("File descriptor already open", 101)
    STREAM_UNSYNCED = ("Stream block index out of sync.", 102)
    NOT_AUTHENTICATED = ("The client is not authenticated", 103)


class ClientCollectStateMachine(WaypointState):
    """Mail collection state client-side."""

    def __init__(self):
        self.note = None
        self._event = asyncio.Event()
        WaypointState.__init__(self, {
            "ready": ("collect",),
            "collect": ("note",),
            "note": ("collect", "accomplished"),
            "accomplished": tuple(),
        })
        self._state = "ready"

    @property
    def event(self) -> asyncio.Event:
        """Expose event."""
        return self._event


class ServerCollectStateMachine(WaypointState):
    """Mail collection state server-side."""

    def __init__(self):
        WaypointState.__init__(self, {
            "ready": ("collect",),
            "collect": ("note",),
            "note": ("collect", "accomplished"),
            "accomplished": tuple(),
        })
        self._state = "ready"


class ReceiveSession(ProtocolSession):
    def __init__(self, server: bool, session: int):
        ProtocolSession.__init__(self, SESH_TYPE_RECEIVE, session, dict(), server)
        self._collection = ServerCollectStateMachine() if server else ClientCollectStateMachine()

    @property
    def collection(self) -> WaypointState:
        """Exposing the internal collection state."""
        return self._collection


class CollectPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Request to collect a mail from server."""


class DispatchNotePacket(
    Packet, fields=("file", "count", "length", "created", "modified", "type", "session"),
    fields_info=((DataType.BYTES_FIX, 16), (DataType.UINT,), (DataType.UINT,), (DataType.DATETIME,),
                 (DataType.DATETIME,), (DataType.UINT,), (DataType.UINT,))):
    """Response to mail collect request."""


class ClientPullStateMachine(WaypointState):
    """Mail collection state client-side."""

    def __init__(self):
        self.block = None
        self._event = asyncio.Event()
        WaypointState.__init__(self, {
            "ready": ("pull",),
            "pull": ("block",),
            "block": ("pull", "accomplished"),
            "accomplished": tuple(),
        })
        self._state = "ready"

    @property
    def event(self) -> asyncio.Event:
        """Expose event."""
        return self._event


class ServerPullStateMachine(WaypointState):
    """Mail collection state server-side."""

    def __init__(self):
        WaypointState.__init__(self, {
            "ready": ("pull",),
            "pull": ("block",),
            "block": ("pull", "accomplished"),
            "accomplished": tuple(),
        })
        self._state = "ready"


class DownloadSession(ProtocolSession):
    def __init__(self, server: bool, session: int, file: uuid.UUID, count: int = 0):
        ProtocolSession.__init__(self, SESH_TYPE_DOWNLOAD, session, {
            ST_FILE_ID: file.bytes,
            ST_BLOCK_CNT: hex(count)[2:].encode()
        }, server)
        self._pull = ServerPullStateMachine() if server else ClientPullStateMachine()

    @property
    def pull(self) -> WaypointState:
        """Exposing the internal collection state."""
        return self._pull


class PullPacket(Packet, fields=("block", "type", "session"),
                 fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Request to collect a block from server."""


class BlockPacket(Packet, fields=("digest", "data", "type", "session"), fields_info=(
        (DataType.BYTES_FIX, 20), (DataType.BYTES_FIX, 4008), (DataType.UINT,), (DataType.UINT,))):
    """Response to mail collect request."""


class SendSession(ProtocolSession):
    def __init__(self, server: bool, session: int):
        ProtocolSession.__init__(self, SESH_TYPE_SEND, session, dict(), server)


class UploadSession(ProtocolSession):
    def __init__(self, server: bool, session: int, file: uuid.UUID = uuid.UUID(int=0), count: int = 0):
        ProtocolSession.__init__(self, SESH_TYPE_UPLOAD, session, {
            ST_FILE_ID: file.bytes,
            ST_BLOCK_CNT: hex(count)[2:].encode()
        }, server)


class MailHandler(Handler):
    """Base handler for mail."""

    LEVEL = 2
    RANGE = 2

    SESH_RECEIVE = SESH_TYPE_RECEIVE
    SESH_SEND = SESH_TYPE_SEND
    SESH_DOWNLOAD = SESH_TYPE_DOWNLOAD
    SESH_UPLOAD = SESH_TYPE_UPLOAD

    ST_VERSION = 0x01

    PKT_COLLECT = COLLECT_PACKET
    PKT_DISPATCH = DISPATCH_NOTE_PACKET
    PKT_PULL = PULL_PACKET
    PKT_BLOCK = BLOCK_PACKET

    PACKETS = {
        PKT_COLLECT: CollectPacket,
        PKT_DISPATCH: DispatchNotePacket,
        PKT_PULL: PullPacket,
        PKT_BLOCK: BlockPacket,
        **Handler.PACKETS
    }

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_VERSION: b"mail-0.1",
        }, {
            self.SESH_SEND: SendSession,
            self.SESH_RECEIVE: ReceiveSession,
            self.SESH_UPLOAD: UploadSession,
            self.SESH_DOWNLOAD: DownloadSession
        }, 8)
        self._glob_iterator = None  # Vault / mail file glob iterator
        self._fd = None

        server = self._manager.is_server()
        self.PROCESS = {
            self.PKT_COLLECT: "process_collect" if server else None,
            self.PKT_DISPATCH: None if server else "process_dispatch_note",
            self.PKT_PULL: "process_pull" if server else None,
            self.PKT_BLOCK: None if server else "process_block",
            **self.PROCESS
        }

    async def process_collect(self, packet: CollectPacket):
        """Process mail collection request."""
        sesh = self.get_session(packet.id)
        entry, path = await self._glob_iterator()

        if not entry:
            self._manager.send_packet(self.PKT_DONE + self._r_start, self.LEVEL, DonePacket(sesh.type, sesh.id))
        else:
            if self._fd:
                raise MailError(*MailError.FD_ALREADY_OPEN)

            self._fd = self._manager.facade.storage.mail.archive.load(path, True)
            self._manager.send_packet(
                self.PKT_DISPATCH + self._r_start, self.LEVEL, DispatchNotePacket(
                    path, self._fd.stream.count, self._fd.stream.len,
                    entry.created, entry.modified, sesh.type, sesh.id
                )
            )

    async def process_dispatch_note(self, packet: DispatchNotePacket):
        """Process request to show state."""
        sesh = self.get_session(packet.id)
        machine = sesh.collection
        machine.goto("note")
        machine.note = packet
        machine.event.set()

    async def process_pull(self, packet: PullPacket):
        """Process request to show state."""
        sesh = self.get_session(packet.id)
        if packet.block != 0:
            self._fd.stream.next()

        if packet.block != self._fd.stream.block.index:
            raise MailError(*MailError.STREAM_UNSYNCED)

        block = self._fd.stream.block
        self._manager.send_packet(
            self.PKT_BLOCK + self._r_start, self.LEVEL, BlockPacket(block.digest, block.data, sesh.type, sesh.id))

        if block.index == -1:
            self._fd.close()
            self._fd = None

    async def process_block(self, packet: BlockPacket):
        """Process request to show state."""
        sesh = self.get_session(packet.id)
        machine = sesh.pull
        machine.goto("block")
        machine.block = packet
        machine.event.set()


class MailClient(MailHandler):
    """Client side mail handler."""

    def __init__(self, manager: "Protocol"):
        MailHandler.__init__(self, manager)
        print("Client", self.PACKETS, self.PROCESS)

    async def start(self) -> bool:
        """Make authentication against server."""
        user = self._manager.facade.data.portfolio.entity.id

        init = await self.sync(tuple(self._states.keys()))
        if not init:
            raise MailError(*MailError.INIT_FAILED)

        async with self.context(self.SESH_RECEIVE) as sesh_receive:
            async for note in self.collect_iter(sesh_receive):
                path = self._manager.facade.api.mailbox.PATH_INBOX[0].joinpath(PurePosixPath(note.path).name)
                try:
                    await self._manager.facade.storage.vault.archive.mkfile(
                        path, b"", created=note.created, modified=note.modified, owner=user)
                    fd = self._manager.facade.storage.vault.archive.load(path, True)

                    async with self.context(self.SESH_DOWNLOAD, file=note.file, count=note.count) as sesh_download:
                        async for block in self.pull_iter(sesh_download):
                            if hashlib.sha1(self.data).digest() != block.digest:
                                raise BlockError()
                            fd.stream.push(block.data)
                        fd.stream.truncate(note.length)
                    fd.close()
                except BlockError:
                    await self._manager.facade.storage.vault.archive.remove(path)

        async with self.context(self.SESH_SEND) as sesh_send:
            pass

    async def collect_iter(self, sesh: ReceiveSession):
        """Iterator for collecting mails from server."""
        machine = sesh.collection
        while True:
            machine.goto("collect")
            self._manager.send_packet(self.PKT_START, self.LEVEL, CollectPacket(sesh.type, sesh.id))
            await machine.event.wait()
            if machine.note:
                yield machine.note
                machine.note = None
            else:
                break
            machine.event.clear()
        machine.goto("accomplished")

    async def pull_iter(self, sesh: DownloadSession):
        """Iterator for pulling file stream blocks from server."""
        machine = sesh.collection
        for block in range(sesh.states[ST_BLOCK_CNT]):
            machine.goto("pull")
            self._manager.send_packet(self.PKT_START, self.LEVEL, PullPacket(block, sesh.type, sesh.id))
            await machine.event.wait()
            if machine.block:
                yield machine.block
                machine.block = None
            else:
                break
            machine.event.clear()
        machine.goto("accomplished")


class MailServer(MailHandler):
    """Server side mail handler."""

    def __init__(self, manager: "Protocol"):
        MailHandler.__init__(self, manager)
        print("Server", self.PACKETS, self.PROCESS)

    async def session_prepare(self, sesh: ProtocolSession):
        """Call to make preparations for a session."""
        if sesh.type == self.SESH_RECEIVE:
            self._glob_iterator = await self._manager.facade.storage.mail.receive_iter(
                self._manager.portfolio.entity.id)
