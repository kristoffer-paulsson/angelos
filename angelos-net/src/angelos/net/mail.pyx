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
import datetime
import hashlib
import os
import typing
import uuid

from angelos.archive7.fs import FileObject
from angelos.common.misc import SyncCallable, AsyncCallable
from angelos.document.utils import Helper, Definitions
from angelos.net.base import Handler, NetworkIterator, PullItemIterator, PullChunkIterator, \
    PushItemIterator, PushChunkIterator, StateMode, NetworkState, ConfirmCode

MAIL_VERSION = b"mail-0.1"

SESH_TYPE_RECEIVE = 0x01
SESH_TYPE_DOWNLOAD = 0x02
SESH_TYPE_SEND = 0x03
SESH_TYPE_UPLOAD = 0x04


class MailError(RuntimeError):
    """Unrepairable errors in the mail handler."""
    INIT_FAILED = ("Initialization if protocol failed", 100)
    FD_ALREADY_OPEN = ("File descriptor already open", 101)
    STREAM_UNSYNCED = ("Stream block index out of sync.", 102)
    NOT_AUTHENTICATED = ("The client is not authenticated", 103)


class ChunkError(RuntimeWarning):
    """Block data digest mismatch."""
    pass


class ReceiveIterator(PullItemIterator):
    """Test stub iterator item push with states."""

    def __init__(self, server: bool, session: int, check: SyncCallable = None):
        PullItemIterator.__init__(self, server, SESH_TYPE_RECEIVE, session, {
        }, 0, check)
        self._external = None
        self._handler = None

    async def pull_item(self) -> uuid.UUID:
        item = await self._external.__anext__()
        self._handler.set_entry(item)
        return item[0].id

    def external(self, handler: "MailHandler", iterator: typing.Iterator):
        """Set handler and iterator."""
        self._handler = handler
        self._external = iterator


class DownloadIterator(PullChunkIterator):
    """Test stub iterator item push with states."""

    ST_CREATED = 0x02
    ST_MODIFIED = 0x03
    ST_OWNER = 0x04
    ST_NAME = 0x05
    ST_LENGTH = 0x06
    ST_ID = 0x07

    def __init__(self, server: bool, session: int, check: SyncCallable = None):
        PullChunkIterator.__init__(self, server, SESH_TYPE_DOWNLOAD, session, {
            self.ST_CREATED: (StateMode.FACT, b""),
            self.ST_MODIFIED: (StateMode.FACT, b""),
            self.ST_OWNER: (StateMode.FACT, b""),
            self.ST_NAME: (StateMode.FACT, b""),
            self.ST_LENGTH: (StateMode.FACT, b""),
            self.ST_ID: (StateMode.ONCE, b"")
        }, 0, check)
        self._fd = None
        self._handler = None
        self._stream = None

    async def pull_chunk(self) -> typing.Tuple[bytes, bytes]:
        block = self._stream.block
        if block.next == -1:
            self._fd.close()
            await self._handler.del_entry()
        else:
            self._stream.next()
        return block.data, block.digest

    def external(self, handler: "MailHandler", fd: FileObject):
        """Set handler and iterator."""
        self._handler = handler
        self._fd = fd
        self._stream = fd.stream


class SendIterator(PushItemIterator):
    """Test stub iterator item push with states."""

    def __init__(self, server: bool, session: int, count: int = 0):
        PushItemIterator.__init__(self, server, SESH_TYPE_SEND, session, {
        }, count, SyncCallable(self.count_state))


class UploadIterator(PushChunkIterator):
    """Test stub iterator item push with states."""

    def __init__(self, server: bool, session: int, count: int = 0):
        PushChunkIterator.__init__(self, server, SESH_TYPE_UPLOAD, session, {
        }, count, SyncCallable(self.server_trigger if server else self.count_state))


class MailHandler(Handler):
    """Base handler for mail."""

    LEVEL = 2
    RANGE = 3

    SESH_RECEIVE = SESH_TYPE_RECEIVE
    SESH_DOWNLOAD = SESH_TYPE_DOWNLOAD
    SESH_SEND = SESH_TYPE_SEND
    SESH_UPLOAD = SESH_TYPE_UPLOAD

    ST_VERSION = 0x01

    def __init__(self, manager: "Protocol", receive: SyncCallable = None, download: SyncCallable = None):
        server = manager.is_server()
        Handler.__init__(self, manager, states={
            self.ST_VERSION: (StateMode.MEDIATE, MAIL_VERSION),
        },
        sessions={
            self.SESH_RECEIVE: (ReceiveIterator, {"check": receive} if server else dict()),
            self.SESH_DOWNLOAD: (DownloadIterator, {"check": download} if server else dict()),
            self.SESH_SEND: (SendIterator, {} if server else dict()),
            self.SESH_UPLOAD: (UploadIterator, {} if server else dict()),
        }, max_sesh=5)


class MailClient(MailHandler):
    """Client side mail handler."""

    def __init__(self, manager: "Protocol"):
        MailHandler.__init__(self, manager)

    async def exchange(self):
        """Send and receive messages."""
        user = self._manager.facade.data.portfolio.entity.id

        await self._receive_mails()
        # await self._send_mails()

    async def _receive_mails(self):
        """Iterate over received mails."""
        async with self._sesh_context(self.SESH_RECEIVE) as sesh:
            answer, data = await self._call_query(NetworkIterator.ST_COUNT, sesh)
            count = int.from_bytes(data, "big", signed=False)
            async for item in self._iter_pull_item(sesh, count):
                await self._download(item)

    async def _download(self, item: uuid.UUID):
        """Download received mail."""
        async with self._sesh_context(self.SESH_DOWNLOAD) as sesh:
            sesh.states[DownloadIterator.ST_ID].update(item.bytes)
            await self._call_tell(DownloadIterator.ST_ID, sesh)

            count = int.from_bytes((await self._call_query(NetworkIterator.ST_COUNT, sesh))[1], "big", signed=False)
            created = datetime.datetime.fromisoformat(
                (await self._call_query(DownloadIterator.ST_CREATED, sesh))[1].decode())
            modified = datetime.datetime.fromisoformat(
                (await self._call_query(DownloadIterator.ST_MODIFIED, sesh))[1].decode())
            owner = uuid.UUID(bytes=(await self._call_query(DownloadIterator.ST_OWNER, sesh))[1])
            name = (await self._call_query(DownloadIterator.ST_NAME, sesh))[1]
            length = int.from_bytes((await self._call_query(DownloadIterator.ST_LENGTH, sesh))[1], "big", signed=False)

            path = self._manager.facade.api.mailbox.PATH_INBOX[0].joinpath(
                str(name) + Helper.extension(Definitions.COM_ENVELOPE))

            try:
                await self._manager.facade.storage.vault.archive.mkfile(
                    path, b"", created=created, modified=modified, owner=owner, id=item)
                fd = await self._manager.facade.storage.vault.archive.load(path, True, False)
                async for chunk, digest in self._iter_pull_chunk(sesh, count):
                    if hashlib.sha1(chunk).digest() != digest:
                        raise ChunkError()
                    fd.write(chunk)
                fd.truncate(length)
                fd.close()
            except ChunkError:
                await self._manager.facade.storage.vault.archive.remove(path)

    async def _send_mails(self):
        """Iterate over sent mails."""
        items = list()
        async with self._sesh_context(self.SESH_SEND) as sesh:
            answer, data = await self._call_query(NetworkIterator.ST_COUNT, sesh)
            count = int.from_bytes(data, "big", signed=False)
            async for item in self._iter_pull_item(sesh, count):
                items.append(item)
        return items

    async def _upload(self):
        """Upload sent mail."""
        async with self._sesh_context(self.SESH_UPLOAD, count=5) as sesh:
            await self._call_tell(NetworkIterator.ST_COUNT, sesh)
            for chunk in [os.urandom(4096) for _ in range(5)]:
                await self._push_chunk(sesh, chunk)


class MailServer(MailHandler):
    """Server side mail handler."""

    def __init__(self, manager: "Protocol"):
        MailHandler.__init__(
            self, manager,
            receive=AsyncCallable(self._receive_items),
            download=AsyncCallable(self._download_chunks)
        )
        self._item = None

    async def _receive_items(self, state: NetworkState, sesh: ReceiveIterator) -> int:
        """Prepare ReceiveIterator with an iterator."""
        sesh.external(self, self._manager.facade.storage.mail.receive_iter(self._manager.portfolio.entity.id))
        state.update(b"?")
        return ConfirmCode.YES

    def set_entry(self, item: tuple):
        if self._item:
            raise TypeError("Current item already set.")
        self._item = item

    async def _download_chunks(self, state: NetworkState, sesh: ReceiveIterator) -> int:
        """Prepare DownloadIterator with file information and chunk count."""
        if not self._item:
            raise TypeError("No current item set.")

        if sesh.states[DownloadIterator.ST_ID].value != self._item[0].id.bytes:
            raise TypeError("Current item out of sync with session.")

        fd = await self._manager.facade.storage.mail.archive.load(self._item[1], True)
        sesh.external(self, fd)

        state.update(fd.stream.count.to_bytes(8, "big", signed=False))
        sesh.states[DownloadIterator.ST_CREATED].update(self._item[0].created.isoformat().encode())
        sesh.states[DownloadIterator.ST_MODIFIED].update(self._item[0].modified.isoformat().encode())
        sesh.states[DownloadIterator.ST_OWNER].update(self._item[0].owner.bytes)
        sesh.states[DownloadIterator.ST_NAME].update(self._item[0].name)
        sesh.states[DownloadIterator.ST_LENGTH].update(self._item[0].length.to_bytes(8, "big", signed=False))

    async def del_entry(self):
        await self._manager.facade.storage.mail.archive.remove(self._item[1])
        self._item = None

