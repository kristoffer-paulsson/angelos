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

from angelos.document.utils import Helper as DocumentHelper, Definitions
from angelos.lib.error import Error
from angelos.document.types import MessageT
from angelos.lib.policy.format import PrintPolicy
from angelos.facade.facade import ApiFacadeExtension, Facade
from angelos.document.envelope import Envelope
from angelos.document.messages import Message, Mail
from angelos.document.misc import StoredLetter
from angelos.lib.helper import Glue
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.envelope.open import OpenEnvelope
from angelos.portfolio.envelope.receive import ReceiveEnvelope
from angelos.portfolio.envelope.validate import ValidateEnvelope
from angelos.portfolio.envelope.wrap import WrapEnvelope
from angelos.portfolio.message.create import CreateMail
from angelos.portfolio.message.validate import ValidateMessage
from angelos.portfolio.utils import Groups


class MailboxAPI(ApiFacadeExtension):
    """An interface class to be placed on the facade."""

    ATTRIBUTE = ("mailbox",)

    PATH_INBOX = (PurePosixPath("/messages/inbox"),)
    PATH_OUTBOX = (PurePosixPath("/messages/outbox"),)
    PATH_READ = (PurePosixPath("/messages/read"),)
    PATH_DRAFT = (PurePosixPath("/messages/drafts"),)
    PATH_TRASH = (PurePosixPath("/messages/trash"),)
    PATH_SENT = (PurePosixPath("/messages/sent"),)
    PATH_CACHE = (PurePosixPath("/cache/msg"),)

    SUFFIX_ENVELOPE = DocumentHelper.extension(Definitions.COM_ENVELOPE)
    SUFFIX_MAIL = DocumentHelper.extension(Definitions.COM_MAIL)
    SUFFIX_CHACHED = DocumentHelper.extension(Definitions.CACHED_MSG)

    def __init__(self, facade: Facade):
        """Initialize the Mail."""
        ApiFacadeExtension.__init__(self, facade)

    async def __load_letters(self, pattern: str) -> Set[uuid.UUID]:
        """Loads all letters according to pattern."""
        result = await self.facade.storage.vault.search(
            pattern,
            limit=0,
            deleted=False,
            fields=lambda name, entry: (entry.owner, entry.name.decode())
        )
        return set(result.keys())

    async def load_inbox(self) -> Set[uuid.UUID]:
        """Load envelopes from the inbox."""
        return await self.__load_letters(str(self.PATH_INBOX[0].joinpath("*")))

    async def load_outbox(self) -> Set[uuid.UUID]:
        """Load letters from outbox folder."""
        return await self.__load_letters(str(self.PATH_OUTBOX[0].joinpath("*")))

    async def load_read(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store."""
        return await self.__load_letters(str(self.PATH_READ[0].joinpath("*")))

    async def load_drafts(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store."""
        return await self.__load_letters(str(self.PATH_DRAFT[0].joinpath("*")))

    async def load_trash(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store."""
        return await self.__load_letters(str(self.PATH_TRASH[0].joinpath("*")))

    async def load_sent(self) -> Set[uuid.UUID]:
        """Load read folder from the messages store."""
        return await self.__load_letters(str(self.PATH_SENT[0].joinpath("*")))

    async def __info_mail(self, filename: PurePosixPath) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """Get info about a mail."""
        error = False

        letter = await self.facade.storage.vault.archive.load(filename)
        mail = DocumentHelper.deserialize(letter)
        if not isinstance(mail, Mail):
            error = True
        sender = await self.facade.storage.vault.load_portfolio(mail.issuer, Groups.VERIFIER)
        message = ValidateMessage().validate(self.facade.data.portfolio, sender, mail)
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
        """Get info about a draft."""
        error = False

        letter = await self.facade.storage.vault.archive.load(filename)
        mail = DocumentHelper.deserialize(letter)
        if not isinstance(mail, Mail):
            error = True
        receiver = await self.facade.storage.vault.load_portfolio(mail.owner, Groups.VERIFIER)

        return (
            error, mail.owner, mail.subject, PrintPolicy.title(receiver), mail.reply,
            len(mail.attachments) if mail.attachments is list else int(bool(mail.attachments))
        )

    async def __info_inbox_envelope(self, filename: PurePosixPath) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime, bool, bool, bool]:
        """Get info about an envelope."""
        error = False

        letter = await self.facade.storage.vault.archive.load(filename)
        envelope = DocumentHelper.deserialize(letter)
        if not isinstance(envelope, Envelope):
            error = True
        sender = await self.facade.storage.vault.load_portfolio(envelope.issuer, Groups.VERIFIER)
        message = ValidateEnvelope().validate(self.facade.data.portfolio, sender, envelope)
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
        """Get info about an envelope."""
        error = False

        letter = await self.facade.storage.vault.archive.load(filename)
        envelope = DocumentHelper.deserialize(letter)
        if not isinstance(envelope, Envelope):
            error = True
        receiver = await self.facade.storage.vault.load_portfolio(envelope.owner, Groups.VERIFIER)
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
        filename = MailboxAPI.PATH_INBOX[0].joinpath(str(envelope_id) + self.SUFFIX_ENVELOPE)
        return await self.__info_inbox_envelope(filename)

    async def get_info_outbox(self,  envelope_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime]:
        """

        Args:
            envelope_id:

        Returns:

        """
        filename = MailboxAPI.PATH_OUTBOX[0].joinpath(str(envelope_id) + self.SUFFIX_ENVELOPE)
        return await self.__info_outbox_envelope(filename)

    async def get_info_draft(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = MailboxAPI.PATH_DRAFT[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        return await self.__info_draft(filename)

    async def get_info_read(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = MailboxAPI.PATH_READ[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        return await self.__info_mail(filename)

    async def get_info_trash(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = MailboxAPI.PATH_TRASH[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        return await self.__info_mail(filename)

    async def get_info_sent(self, message_id: uuid.UUID) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """

        Args:
            message_id:

        Returns:

        """
        filename = MailboxAPI.PATH_SENT[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        return await self.__info_mail(filename)

    async def __simple_load(self, filename: PurePosixPath) -> MessageT:
        """Loads messages without policy checks."""
        return DocumentHelper.deserialize(await self.facade.storage.vault.archive.load(filename))

    async def get_read(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename =  MailboxAPI.PATH_READ[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        return await self.__simple_load(filename)

    async def get_draft(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename =  MailboxAPI.PATH_DRAFT[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        return await self.__simple_load(filename)

    async def get_trash(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename =  MailboxAPI.PATH_TRASH[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        return await self.__simple_load(filename)

    async def get_sent(self, message_id: uuid.UUID) -> MessageT:
        """

        Args:
            message_id:

        Returns:

        """
        filename =  MailboxAPI.PATH_SENT[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
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
            filename = path.joinpath(str(message_id) + self.SUFFIX_MAIL)
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
            filename =  MailboxAPI.PATH_TRASH[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
            is_file = await archive.isfile(filename)
            if is_file:
                await archive.remove(filename)

    async def mail_to_inbox(
        self, envelopes: Envelope
    ) -> (bool, Set[Envelope], bool):
        """Import envelope to inbox. Check owner and then validate."""
        reject = set()
        save_list = list()

        for envelope in envelopes:
            envelope = ReceiveEnvelope().perform(self.facade.data.portfolio, envelope)
            if not envelope:
                reject.add(envelope)
                continue

            save_list.append(
                self.facade.storage.vault.save(
                    MailboxAPI.PATH_INBOX[0].joinpath(str(envelope.id) + self.SUFFIX_MAIL), envelope))

        result = await asyncio.gather(*save_list)
        return True, reject, result

    async def load_envelope(self, envelope_id: uuid.UUID) -> Envelope:
        """Load specific envelope from the inbox."""
        return await self._load_doc(envelope_id, Definitions.COM_ENVELOPE, MailboxAPI.PATH_INBOX[0], Envelope)

    async def load_message(self, message_id: uuid.UUID) -> Mail:
        """Load specific message from the read folder."""
        return await self._load_doc(message_id, Definitions.COM_MAIL, MailboxAPI.PATH_READ[0], Mail)

    async def _load_doc(self, doc_id: uuid.UUID, doc_type_num: int, box_dir: PurePosixPath, doc_class) -> Any:
        doc_list = await self.facade.storage.vault.search_docs(
            path=box_dir.joinpath(str(doc_id) + DocumentHelper.extension(doc_type_num)), limit=1)
        if not doc_list:
            return None
        result = Glue.doc_validate_report(doc_list, doc_class)
        if isinstance(result[0][1], Exception):
            return None

        return result[0][0]

    async def import_envelope(self, envelope: Envelope):
        """Imports an envelope to inbox."""
        result = await self.facade.storage.vault.save(
            MailboxAPI.PATH_INBOX[0].joinpath(str(envelope.id) + self.SUFFIX_MAIL), envelope)
        if isinstance(result, Exception):
            raise result
        return True

    async def open_envelope(self, envelope_id: uuid.UUID) -> MessageT:
        """Open an envelope and verify its content according to policies."""
        vault = self.facade.storage.vault

        # Load and deserialize file into envelope document based on document ID.
        path =  MailboxAPI.PATH_INBOX[0].joinpath(str(envelope_id) + self.SUFFIX_ENVELOPE)
        envelope = DocumentHelper.deserialize(await vault.archive.load(path))

        # Load sender portfolio.
        sender = await vault.load_portfolio(envelope.issuer, Groups.VERIFIER)
        message = OpenEnvelope().perform(self.facade.data.portfolio, sender, envelope)

        # move mail to read, and make complaint backup
        await self.store_letter(envelope, message)
        await self.save_read(message)

        return message

    async def store_letter(self, envelope: Envelope, message: Message):
        """Save a related envelope and message for later complaint."""
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
            MailboxAPI.PATH_CACHE[0].joinpath(str(letter.id) + self.SUFFIX_CHACHED),
            letter, document_file_id_match=False)

        await self.facade.storage.vault.delete(
            MailboxAPI.PATH_INBOX[0].joinpath(str(envelope.id) + self.SUFFIX_ENVELOPE))

    async def save_read(self, message: Mail):
        """Save a message as read in the read message folder."""
        await self.facade.storage.vault.save(
            MailboxAPI.PATH_READ[0].joinpath(str(message.id) + self.SUFFIX_MAIL), message)

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
            recipient if recipient else mail.owner, Groups.VERIFIER)
        builder = CreateMail().perform(self.facade.data.portfolio, recipient)
        message = builder.message(subject, body, reply).done()
        envelope = WrapEnvelope().perform(self.facade.data.portfolio, recipient, message)
        await self.gather(self.remove_draft(mail.id), self.save_outbox(envelope), self.save_sent(message))

    async def remove_draft(self, message_id: uuid.UUID):
        """Remove a mail from the draft folder."""
        filename =  MailboxAPI.PATH_DRAFT[0].joinpath(str(message_id) + self.SUFFIX_MAIL)
        archive = self.facade.storage.vault.archive
        is_file = await archive.isfile(filename)
        if is_file:
            await archive.remove(filename)

    async def save_outbox(self, envelope: Envelope):
        """Save a message to outbox folder to be sent."""
        result = await self.facade.storage.vault.save(
            MailboxAPI.PATH_OUTBOX[0].joinpath(str(envelope.id) + self.SUFFIX_ENVELOPE), envelope)
        if result != envelope.id:
            raise RuntimeError("{}, {}".format(result, envelope.id))

    async def save_sent(self, message: Mail):
        """Save a message to sent folder for archiving."""
        result = await self.facade.storage.vault.save(
            MailboxAPI.PATH_SENT[0].joinpath(str(message.id) + self.SUFFIX_MAIL), message)

    async def save_draft(self, draft: Mail, subject: str, body: str, reply: uuid.UUID=None):
        """Save a message to draft folder for archiving."""
        recipient = await self.facade.storage.vault.load_portfolio(draft.owner, Groups.VERIFIER)
        builder = CreateMail().perform(self.facade.data.portfolio, recipient)
        new_draft = builder.message(subject, body, reply).draft()

        await self.facade.storage.vault.save(
            MailboxAPI.PATH_DRAFT[0].joinpath(str(new_draft.id) + self.SUFFIX_MAIL), new_draft)
        await self.remove_draft(new_draft.id)