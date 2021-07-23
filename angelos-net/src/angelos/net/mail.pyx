# cython: language_level=3, linetrace=True
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
import typing
import uuid
from pathlib import PurePosixPath

from angelos.archive7.fs import FileObject, EntryRecord
from angelos.common.misc import SyncCallable, AsyncCallable
from angelos.document.utils import Helper, Definitions
from angelos.net.base import Handler, NetworkIterator, PullItemIterator, PullChunkIterator, \
    PushItemIterator, PushChunkIterator, StateMode, NetworkState, ConfirmCode, ChunkError

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


class ReceiveIterator(PullItemIterator):
    """Test stub iterator item push with states."""

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PullItemIterator.__init__(self, handler, server, SESH_TYPE_RECEIVE, session, {
        }, 0, check)
        self._iterator = None

    async def pull_item(self) -> uuid.UUID:
        item = await self._iterator.__anext__()
        self._handler.set_entry(item)
        return item[0].id

    def iterator_of_source(self, iterator: typing.Iterator):
        """Set handler and iterator."""
        self._iterator = iterator


class DownloadIterator(PullChunkIterator):
    """Test stub iterator item push with states."""

    ST_CREATED = 0x02
    ST_MODIFIED = 0x03
    ST_OWNER = 0x04
    ST_NAME = 0x05
    ST_LENGTH = 0x06
    ST_ID = 0x07

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PullChunkIterator.__init__(self, handler, server, SESH_TYPE_DOWNLOAD, session, {
            self.ST_CREATED: (StateMode.FACT, b""),
            self.ST_MODIFIED: (StateMode.FACT, b""),
            self.ST_OWNER: (StateMode.FACT, b""),
            self.ST_NAME: (StateMode.FACT, b""),
            self.ST_LENGTH: (StateMode.FACT, b""),
            self.ST_ID: (StateMode.ONCE, b"")
        }, 0, check)
        self._fd = None
        self._stream = None

    async def pull_chunk(self) -> typing.Tuple[bytes, bytes]:
        block = self._stream.block
        if block.next == -1:
            self._fd.close()
            await self._handler.del_entry(True)
        else:
            self._stream.next()
        return block.data, block.digest

    def source(self, fd: FileObject):
        """Set handler and iterator."""
        self._fd = fd
        self._stream = fd.stream


class SendIterator(PushItemIterator):
    """Test stub iterator item push with states."""

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PushItemIterator.__init__(self, handler, server, SESH_TYPE_SEND, session, {
        }, 0, check)

    async def push_item(self, item: uuid.UUID):
        self._handler.set_entry((item,))


class UploadIterator(PushChunkIterator):
    """Test stub iterator item push with states."""

    ST_CREATED = 0x02
    ST_MODIFIED = 0x03
    ST_OWNER = 0x04
    ST_NAME = 0x05
    ST_LENGTH = 0x06
    ST_ID = 0x07

    def __init__(self, handler: "Handler", server: bool, session: int, check: SyncCallable = None):
        PushChunkIterator.__init__(self, handler, server, SESH_TYPE_UPLOAD, session, {
            self.ST_CREATED: (StateMode.ONCE, b""),
            self.ST_MODIFIED: (StateMode.ONCE, b""),
            self.ST_OWNER: (StateMode.ONCE, b""),
            self.ST_NAME: (StateMode.ONCE, b""),
            self.ST_LENGTH: (StateMode.ONCE, b""),
            self.ST_ID: (StateMode.ONCE, b"")
        }, 0, check)
        self._fd = None

    async def push_chunk(self, chunk: bytes, digest: bytes):
        if hashlib.sha1(chunk).digest() != digest:
            raise ChunkError()

        self._fd.write(chunk)

        count = int.from_bytes(self._states[UploadIterator.ST_COUNT].value, "big", signed=False)
        if self._cnt == count:
            self._fd.truncate(int.from_bytes(self._states[UploadIterator.ST_LENGTH].value, "big", signed=False))
            self._fd.close()
            await self._handler.del_entry()

    def source(self, fd: FileObject):
        """Set handler and iterator."""
        self._fd = fd


class MailHandler(Handler):
    """Base handler for mail."""

    LEVEL = 2
    RANGE = 3

    SESH_RECEIVE = SESH_TYPE_RECEIVE
    SESH_DOWNLOAD = SESH_TYPE_DOWNLOAD
    SESH_SEND = SESH_TYPE_SEND
    SESH_UPLOAD = SESH_TYPE_UPLOAD

    ST_VERSION = 0x01

    def __init__(self, manager: "Protocol"):
        server = manager.is_server()
        Handler.__init__(self, manager,
        states={
            self.ST_VERSION: (StateMode.MEDIATE, MAIL_VERSION),
        },
        sessions={
            self.SESH_RECEIVE: (ReceiveIterator, dict()),
            self.SESH_DOWNLOAD: (DownloadIterator, dict()),
            self.SESH_SEND: (SendIterator, dict()),
            self.SESH_UPLOAD: (UploadIterator, dict()),
        }, max_sesh=5)


class MailClient(MailHandler):
    """Client side mail handler."""

    def __init__(self, manager: "Protocol"):
        MailHandler.__init__(self, manager)

    async def exchange(self):
        """Send and receive messages."""
        await self._manager.ready()

        user = self._manager.facade.data.portfolio.entity.id

        await self._receive_mails()
        await self._send_mails()

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
            await self._call_tell(NetworkIterator.ST_COUNT, sesh)
            async for entry, path in self._manager.facade.storage.vault.outbox_iter():
                await self._push_item(sesh, entry.id)
                await self._upload(entry, path)

    async def _block_iter(self, fd: FileObject):
        """Iterate over block in a file descriptor stream."""
        stream = fd.stream

        while True:
            block = stream.block
            yield block.data, block.digest
            if block.next == -1:
                fd.close()
                break
            else:
                stream.next()

    async def _upload(self, entry: EntryRecord, path: PurePosixPath):
        """Upload sent mail."""
        async with self._sesh_context(self.SESH_UPLOAD) as sesh:
            sesh.states[UploadIterator.ST_CREATED].update(entry.created.isoformat().encode())
            await self._call_tell(UploadIterator.ST_CREATED, sesh)
            sesh.states[UploadIterator.ST_MODIFIED].update(entry.modified.isoformat().encode())
            await self._call_tell(UploadIterator.ST_MODIFIED, sesh)
            sesh.states[UploadIterator.ST_OWNER].update(entry.owner.bytes)
            await self._call_tell(UploadIterator.ST_OWNER, sesh)
            sesh.states[UploadIterator.ST_NAME].update(entry.name)
            await self._call_tell(UploadIterator.ST_NAME, sesh)
            sesh.states[UploadIterator.ST_LENGTH].update(entry.length.to_bytes(8, "big", signed=False))
            await self._call_tell(UploadIterator.ST_LENGTH, sesh)

            fd = await self._manager.facade.storage.vault.archive.load(path, True)
            sesh.states[UploadIterator.ST_COUNT].update(fd.stream.count.to_bytes(8, "big", signed=False))

            await self._call_tell(UploadIterator.ST_COUNT, sesh)
            async for chunk, digest in self._block_iter(fd):
                await self._push_chunk(sesh, chunk, digest)

            await self._manager.facade.storage.vault.archive.remove(path)


class MailServer(MailHandler):
    """Server side mail handler."""

    def __init__(self, manager: "Protocol"):
        MailHandler.__init__(self, manager)
        self._sessions[self.SESH_RECEIVE][1]["check"] = AsyncCallable(self._receive_items)
        self._sessions[self.SESH_DOWNLOAD][1]["check"] = AsyncCallable(self._download_chunks)
        self._sessions[self.SESH_SEND][1]["check"] = AsyncCallable(self._send_items)
        self._sessions[self.SESH_UPLOAD][1]["check"] = AsyncCallable(self._upload_chunks)
        self._item = None

    async def _receive_items(self, state: NetworkState, sesh: ReceiveIterator) -> int:
        """Prepare ReceiveIterator with an iterator."""
        sesh.iterator_of_source(self._manager.facade.storage.mail.receive_iter(self._manager.portfolio.entity.id))
        state.update(b"!")
        return ConfirmCode.YES

    def set_entry(self, item: tuple):
        if self._item:
            raise TypeError("Current item already set.")
        self._item = item

    async def _download_chunks(self, state: NetworkState, sesh: DownloadIterator) -> int:
        """Prepare DownloadIterator with file information and chunk count."""
        if not self._item:
            raise TypeError("No current item set.")

        if sesh.states[DownloadIterator.ST_ID].value != self._item[0].id.bytes:
            raise TypeError("Current item out of sync with session.")

        fd = await self._manager.facade.storage.mail.archive.load(self._item[1], True)
        sesh.source(fd)

        state.update(fd.stream.count.to_bytes(8, "big", signed=False))
        sesh.states[DownloadIterator.ST_CREATED].update(self._item[0].created.isoformat().encode())
        sesh.states[DownloadIterator.ST_MODIFIED].update(self._item[0].modified.isoformat().encode())
        sesh.states[DownloadIterator.ST_OWNER].update(self._item[0].owner.bytes)
        sesh.states[DownloadIterator.ST_NAME].update(self._item[0].name)
        sesh.states[DownloadIterator.ST_LENGTH].update(self._item[0].length.to_bytes(8, "big", signed=False))

        return ConfirmCode.YES

    async def del_entry(self, delete: bool = False):
        if delete:
            await self._manager.facade.storage.mail.archive.remove(self._item[1])
        self._item = None

    async def _send_items(self, value: bytes, sesh: SendIterator) -> int:
        """Prepare SendIterator with an iterator."""
        return ConfirmCode.YES if value == b"!" else ConfirmCode.NO

    async def _upload_chunks(self, state: NetworkState, sesh: UploadIterator) -> int:
        """Prepare UploadIterator with file information and chunk count."""
        if not self._item:
            raise TypeError("No current item set.")

        created = datetime.datetime.fromisoformat(
            sesh.states[UploadIterator.ST_CREATED].value.decode())
        modified = datetime.datetime.fromisoformat(
            sesh.states[UploadIterator.ST_MODIFIED].value.decode())
        owner = uuid.UUID(bytes=sesh.states[UploadIterator.ST_OWNER].value)
        name = sesh.states[UploadIterator.ST_NAME].value
        path = PurePosixPath("/" + str(self._item[0]) + Helper.extension(Definitions.COM_ENVELOPE))

        await self._manager.facade.storage.vault.archive.mkfile(
            path, b"", created=created, modified=modified, owner=owner, id=self._item[0])
        sesh.source(await self._manager.facade.storage.vault.archive.load(path, True, False))

        return ConfirmCode.YES

