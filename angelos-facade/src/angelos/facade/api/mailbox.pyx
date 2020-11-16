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
"""Facade mail API."""
import asyncio
import datetime
import uuid
from pathlib import PurePosixPath
from typing import Set, Any, Tuple

from angelos.lib.error import Error
from angelos.document.types import MessageT
from angelos.lib.policy.format import PrintPolicy
from angelos.facade.facade import ApiFacadeExtension, Facade
from angelos.document.document import DocType
from angelos.document.envelope import Envelope
from angelos.document.messages import Message, Mail
from angelos.document.misc import StoredLetter
from angelos.lib.helper import Glue
from angelos.lib.policy.accept import ImportPolicy
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.message import EnvelopePolicy, MessagePolicy
from angelos.lib.policy.portfolio import DOCUMENT_PATH, PortfolioPolicy, PGroup


class MailboxAPI(ApiFacadeExtension):
    """An interface class to be placed on the facade."""

    ATTRIBUTE = ("mailbox",)

    PATH_INBOX = ("/messages/inbox",)
    PATH_OUTBOX = ("/messages/outbox",)
    PATH_READ = ("/messages/read",)
    PATH_DRAFT = ("/messages/drafts",)
    PATH_TRASH = ("/messages/trash",)
    PATH_SENT = ("/messages/sent",)
    PATH_CACHE = ("/cache/msg",)

    def __init__(self, facade: Facade):
        """Initialize the Mail.

        Args:
            facade:
        """
        ApiFacadeExtension.__init__(self, facade)

    async def __load_letters(self, pattern: str) -> Set[uuid.UUID]:
        """Loads all letters according to pattern.

        Args:
            pattern (str):
                Search pattern for specific contact folder

        Returns (Set[Tuple[uuid.UUID, uuid.UUID, str]]):
            A set of tuples containing (file id, owner id, filename)

        """
        result = await self.facade.storage.vault.search(
            pattern,
            limit=0,
            deleted=False,
            fields=lambda name, entry: (entry.owner, entry.name.decode())
        )
        return set(result.keys())

    async def load_inbox(self) -> Set[uuid.UUID]:
        """Load envelopes from the inbox.

        Returns:

        """
        return await self.__load_letters(self.PATH_INBOX[0] + "*")

    async def load_outbox(self) -> Set[uuid.UUID]:
        """Load letters from outbox folder.

        Returns:

        """
        return await self.__load_letters(self.PATH_OUTBOX[0] + "*")

    async def load_read(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store.

        Returns:

        """
        return await self.__load_letters(self.PATH_READ[0] + "*")

    async def load_drafts(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store.

        Returns:

        """
        return await self.__load_letters(self.PATH_DRAFT[0] + "*")

    async def load_trash(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store.

        Returns:

        """
        return await self.__load_letters(self.PATH_TRASH[0] + "*")

    async def load_sent(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store.

        Returns:

        """
        return await self.__load_letters(self.PATH_SENT[0] + "*")

    async def __info_mail(self, filename: PurePosixPath) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """Get info about a mail.

        Args:
            filename (str):
                File name of message

        Returns (Tuple[bool, str, str, datetime.datetime, uuid.UUID, int]):
            Information about the message.
                error (int):
                    Was any errors encountered?
                issuer (uuid.UUID):
                    The sender UUID.
                subject (str):
                    Subject of the mail.
                sender (str):
                    Name of the sender.
                posted (datetime.datetime):
                    When the mail was posted.
                reply (uuid.UUID):
                    The forgoing message.
                attachments (int):
                    Number of attachments if any.

        """
        error = False

        letter = await self.facade.storage.vault.archive.load(filename)
        mail = PortfolioPolicy.deserialize(letter)
        if not isinstance(mail, Mail):
            error = True
        sender = await self.facade.storage.vault.load_portfolio(mail.issuer, PGroup.VERIFIER)
        policy = ImportPolicy(self.facade.data.portfolio)
        message = policy.message(sender, mail)
        if not message:
            error = True

        return (
            error,
            mail.issuer,
            mail.subject,
            PrintPolicy.title(sender),
            mail.posted,
            mail.reply,
            len(mail.attachments) if mail.attachments is list else int(bool(mail.attachments))
        )

    async def __info_draft(self, filename: PurePosixPath) -> Tuple[
        bool, uuid.UUID, str, str, uuid.UUID, int]:
        """Get info about a draft.

        Args:
            filename (str):
                File name of message

        Returns (Tuple[bool, str, str, datetime.datetime, uuid.UUID, int]):
            Information about the message.
                error (int):
                    Was any errors encountered?
                owner (uuid.UUID):
                    The receiver UUID.
                subject (str):
                    Subject of the mail.
                receiver (str):
                    Name of the receiver.
                reply (uuid.UUID):
                    The forgoing message.
                attachments (int):
                    Number of attachments if any.

        """
        error = False

        letter = await self.facade.storage.vault.archive.load(filename)
        mail = PortfolioPolicy.deserialize(letter)
        if not isinstance(mail, Mail):
            error = True
        receiver = await self.facade.storage.vault.load_portfolio(mail.owner, PGroup.VERIFIER)

        return (
            error,
            mail.owner,
            mail.subject,
            PrintPolicy.title(receiver),
            mail.reply,
            len(mail.attachments) if mail.attachments is list else int(bool(mail.attachments))
        )

    async def __info_inbox_envelope(self, filename: PurePosixPath) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime, bool, bool, bool]:
        """Get info about an envelope.

        Args:
            filename (str):
                File name of message

        Returns (Tuple[bool, uuid.UUID, str, datetime.datetime, bool, bool, bool]):
            Information about the message.
                error (int):
                    Was any errors encountered?
                issuer (uuid.UUID):
                    The sender UUID.
                sender (str):
                    Name of the sender.
                posted (datetime.datetime):
                    When the mail was posted.
                favorite (bool):
                    Sender is a favorite.
                friend (bool):
                    Sender is a friend
                blocked (bool):
                    Sender is blocked

        """
        error = False

        letter = await self.facade.storage.vault.archive.load(filename)
        envelope = PortfolioPolicy.deserialize(letter)
        if not isinstance(envelope, Envelope):
            error = True
        sender = await self.facade.storage.vault.load_portfolio(envelope.issuer, PGroup.VERIFIER)
        policy = ImportPolicy(self.facade.data.portfolio)
        message = policy.envelope(sender, envelope)
        status = await self.facade.api.contact.status(envelope.issuer)

        if not message:
            error = True

        return (
            error,
            envelope.issuer,
            PrintPolicy.title(sender),
            envelope.posted,
        ) + status

    async def __info_outbox_envelope(self, filename: PurePosixPath) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime]:
        """Get info about an envelope.

        Args:
            filename (str):
                File name of message

        Returns (Tuple[bool, str, datetime.datetime]):
            Information about the message.
                error (int):
                    Was any errors encountered?
                owner (uuid.UUID):
                    The receiver UUID.
                sender (str):
                    Name of the sender.
                posted (datetime.datetime):
                    When the mail was posted.

        """
        error = False


        letter = await self.facade.storage.vault.archive.load(filename)
        envelope = PortfolioPolicy.deserialize(letter)
        if not isinstance(envelope, Envelope):
            error = True
        receiver = await self.facade.storage.vault.load_portfolio(envelope.owner, PGroup.VERIFIER)
        if not envelope.validate():
            error = True

        return (
            error,
            envelope.owner,
            PrintPolicy.title(receiver),
            envelope.posted,
        )

    async def get_info_inbox(self, envelope_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime, bool, bool, bool]:
        """

        Args:
            envelope_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
            dir=MailboxAPI.PATH_INBOX[0], file=envelope_id
        ))
        return await self.__info_inbox_envelope(filename)

    async def get_info_outbox(self,  envelope_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime]:
        """

        Args:
            envelope_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
            dir=MailboxAPI.PATH_OUTBOX[0], file=envelope_id
        ))
        return await self.__info_outbox_envelope(filename)

    async def get_info_draft(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_DRAFT[0], file=message_id
        ))
        return await self.__info_draft(filename)

    async def get_info_read(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_READ[0], file=message_id
        ))
        return await self.__info_mail(filename)

    async def get_info_trash(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_TRASH[0], file=message_id
        ))
        return await self.__info_mail(filename)

    async def get_info_sent(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_SENT[0], file=message_id
        ))
        return await self.__info_mail(filename)

    async def __simple_load(self, filename: PurePosixPath) -> MessageT:
        """Loads messages without policy checks.

        Only use on messages you trust have been validated and
        verified before.

        Args:
            filename (str):
                The filename of the message

        Returns (MessageT):
            Loaded and deserialized message

        """
        return PortfolioPolicy.deserialize(await self.facade.storage.vault.archive.load(filename))

    async def get_read(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_READ[0], file=message_id
        ))
        return await self.__simple_load(filename)

    async def get_draft(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_DRAFT[0], file=message_id
        ))
        return await self.__simple_load(filename)

    async def get_trash(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_TRASH[0], file=message_id
        ))
        return await self.__simple_load(filename)

    async def get_sent(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_SENT[0], file=message_id
        ))
        return await self.__simple_load(filename)

    async def move_trash(self, message_id: uuid.UUID):
        """

        Args:
            message_id:

        Returns:

        """
        for path in (
                MailboxAPI.PATH_READ[0],
                MailboxAPI.PATH_DRAFT[0],
                MailboxAPI.PATH_SENT[0]
        ):
            filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=path.rstrip("/"), file=message_id
            ))
            archive = self.facade.storage.vault.archive
            is_file = await archive.isfile(filename)
            if is_file:
                await archive.move(filename, MailboxAPI.PATH_TRASH[0])
                break

    async def empty_trash(self):
        """

        Returns:

        """
        trash = await self.load_trash()
        archive = self.facade.storage.vault.archive
        for message_id in trash:
            filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=MailboxAPI.PATH_TRASH[0], file=message_id
            ))
            is_file = await archive.isfile(filename)
            if is_file:
                await archive.remove(filename)

    async def mail_to_inbox(
        self, envelopes: Envelope
    ) -> (bool, Set[Envelope], bool):
        """Import envelope to inbox. Check owner and then validate.

        Args:
            envelopes:

        Returns:

        """
        reject = set()
        save_list = list()

        for envelope in envelopes:
            envelope = EnvelopePolicy.receive(self.facade.data.portfolio, envelope)
            if not envelope:
                reject.add(envelope)
                continue

            save_list.append(
                self.facade.storage.vault.save(
                    PurePosixPath(DOCUMENT_PATH[envelope.type].format(
                        dir=MailboxAPI.PATH_INBOX[0], file=envelope.id
                    )),
                    envelope,
                )
            )

        result = await asyncio.gather(*save_list)
        return True, reject, result

    async def load_envelope(self, envelope_id: uuid.UUID) -> Envelope:
        """Load specific envelope from the inbox.

        Args:
            envelope_id:

        Returns:

        """
        return await self._load_doc(envelope_id, DocType.COM_ENVELOPE, MailboxAPI.PATH_INBOX[0], Envelope)

    async def load_message(self, message_id: uuid.UUID) -> Mail:
        """Load specific message from the read folder.

        Args:
            message_id:

        Returns:

        """
        return await self._load_doc(message_id, DocType.COM_MAIL, MailboxAPI.PATH_READ[0], Mail)

    async def _load_doc(self, doc_id: uuid.UUID, doc_type_num, box_dir, doc_class) -> Any:
        doc_list = await self.facade.storage.vault.search_docs(
            path=PurePosixPath(DOCUMENT_PATH[doc_type_num].format(
                dir=box_dir, file=doc_id
            )),
            limit=1,
        )
        if not doc_list:
            return None
        result = Glue.doc_validate_report(doc_list, doc_class)
        if isinstance(result[0][1], Exception):
            return None

        return result[0][0]

    async def import_envelope(self, envelope: Envelope):
        """Imports an envelope to inbox.

        Args:
            envelope:

        Returns:

        """
        result = await self.facade.storage.vault.save(
            PurePosixPath(DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=MailboxAPI.PATH_INBOX[0], file=envelope.id
            )),
            envelope,
        )
        if isinstance(result, Exception):
            raise result
        return True

    async def open_envelope(self, envelope_id: uuid.UUID) -> MessageT:
        """Open an envelope and verify its content according to policies.

        Args:
            envelope_id (uuid.UUID):
                The envelope filename within the inbox folder.

        Returns (MessageT):
            Verified message document

        """
        vault = self.facade.storage.vault

        # Load and deserialize file into envelope document based on document ID.
        path = PurePosixPath(DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
            dir=MailboxAPI.PATH_INBOX[0], file=envelope_id))
        envelope = PortfolioPolicy.deserialize(await vault.archive.load(path))

        # Load sender portfolio.
        sender = await vault.load_portfolio(envelope.issuer, PGroup.VERIFIER)
        message = EnvelopePolicy.open(self.facade.data.portfolio, sender, envelope)

        # move mail to read, and make complaint backup
        await self.store_letter(envelope, message)
        await self.save_read(message)

        return message

    async def store_letter(self, envelope: Envelope, message: Message):
        """Save a related envelope and message for later complaint.

        The calling function is responsible for opening the envelope and
        applying the necessary policies.

        Args:
            envelope (Envelope):
            message (Message):

        Returns:

        """
        if envelope.issuer != message.issuer:
            raise Error.exception(Error.MAILBOX_STORE_ISSUER_MISSMATCH, {
                "envelope": envelope.id, "message": message.id,
                "envelope_issuer": envelope.issuer, "message_issuer": message.issuer})

        if envelope.owner != message.owner:
            raise Error.exception(Error.MAILBOX_STORE_OWNER_MISSMATCH, {
                "envelope": envelope.id, "message": message.id,
                "envelope_owner": envelope.owner, "message_owner": message.owner})

        if abs(envelope.posted - message.posted) > datetime.timedelta(seconds=60):
            raise Error.exception(Error.MAILBOX_STORE_TIMESTMP_MISSMATCH, {
                "envelope": envelope.id, "message": message.id,
                "envelope_owner": envelope.owner, "message_owner": message.owner})

        letter = StoredLetter(nd={
            "id": message.id,
            "issuer": self.facade.data.portfolio.entity.id,
            "envelope": envelope,
            "message": message,
        })
        letter = Crypto.sign(letter, self.facade.data.portfolio)
        letter.validate()

        await self.facade.storage.vault.save(
            PurePosixPath(DOCUMENT_PATH[DocType.CACHED_MSG].format(
                dir=MailboxAPI.PATH_CACHE[0], file=letter.id)),
            letter,
            document_file_id_match=False
        )

        await self.facade.storage.vault.delete(
            PurePosixPath(DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=MailboxAPI.PATH_INBOX[0], file=envelope.id
            ))
        )

    async def save_read(self, message: Mail):
        """Save a message as read in the read message folder.

        Args:
            message (Mail):
                Message to be saved as read.

        Returns:

        """
        await self.facade.storage.vault.save(
            PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=MailboxAPI.PATH_READ[0], file=message.id
            )),
            message
        )

    async def send_mail(self, mail: Mail, subject: str, body: str, recipient: uuid.UUID=None, reply: uuid.UUID=None):
        """

        Args:
            mail:
            subject:
            body:
            recipient:
            reply:

        Returns:

        """
        recipient = await self.facade.storage.vault.load_portfolio(
            recipient if recipient else mail.owner, PGroup.VERIFIER)
        builder = MessagePolicy.mail(self.facade.data.portfolio, recipient)
        message = builder.message(subject, body, reply).done()
        envelope = EnvelopePolicy.wrap(self.facade.data.portfolio, recipient, message)
        await self.gather(
            self.remove_draft(mail.id),
            self.save_outbox(envelope),
            self.save_sent(message)
        )

    async def remove_draft(self, message_id: uuid.UUID):
        """Remove a mail from the draft folder.

        Args:
            message_id (uuid.UUID):
                The message ID of the draft.

        Returns:

        """
        filename = PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=MailboxAPI.PATH_DRAFT[0], file=message_id
        ))
        archive = self.facade.storage.vault.archive
        is_file = await archive.isfile(filename)
        if is_file:
            await archive.remove(filename)

    async def save_outbox(self, envelope: Envelope):
        """Save a message to outbox folder to be sent.

        Args:
            envelope:

        Returns:

        """
        result = await self.facade.storage.vault.save(
            PurePosixPath(DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=MailboxAPI.PATH_OUTBOX[0], file=envelope.id
            )),
            envelope,
        )
        if result != envelope.id:
            raise RuntimeError("{}, {}".format(result, envelope.id))

    async def save_sent(self, message: Mail):
        """Save a message to sent folder for archiving.

        Args:
            message:

        Returns:

        """
        result = await self.facade.storage.vault.save(
            PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=MailboxAPI.PATH_SENT[0], file=message.id
            )),
            message,
        )

    async def save_draft(self, draft: Mail, subject: str, body: str, reply: uuid.UUID=None):
        """Save a message to draft folder for archiving.

        Args:
            draft:
            subject:
            body:
            reply:

        Returns:

        """
        recipient = await self.facade.storage.vault.load_portfolio(draft.owner, PGroup.VERIFIER)
        builder = MessagePolicy.mail(self.facade.data.portfolio, recipient)
        new_draft = builder.message(subject, body, reply).draft()

        await self.facade.storage.vault.save(
            PurePosixPath(DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=MailboxAPI.PATH_DRAFT[0], file=new_draft.id
            )),
            new_draft,
        )
        await self.remove_draft(new_draft.id)