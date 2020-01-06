# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Facade mail API."""
import asyncio
import datetime
import os
import uuid
from typing import Set, Any, Tuple

from libangelos.policy.print import PrintPolicy
from libangelos.api.api import ApiFacadeExtension
from libangelos.document.document import DocType
from libangelos.document.envelope import Envelope
from libangelos.document.messages import Message, Mail
from libangelos.document.misc import StoredLetter
from libangelos.facade.base import BaseFacade
from libangelos.helper import Glue
from libangelos.policy.accept import ImportPolicy
from libangelos.policy.crypto import Crypto
from libangelos.policy.message import EnvelopePolicy
from libangelos.policy.portfolio import DOCUMENT_PATH, PortfolioPolicy, PGroup

class MailboxAPI(ApiFacadeExtension):
    """An interface class to be placed on the facade."""

    ATTRIBUTE = ("mailbox",)

    PATH_INBOX = ("/messages/inbox/",)
    PATH_OUTBOX = ("/messages/outbox/",)
    PATH_READ = ("/messages/read/",)
    PATH_DRAFT = ("/messages/drafts/",)
    PATH_TRASH = ("/messages/trash/",)
    PATH_SENT = ("/messages/sent/",)
    PATH_CACHE = ("/cache/msg/",)

    def __init__(self, facade: BaseFacade):
        """Initialize the Mail."""
        ApiFacadeExtension.__init__(self, facade)

    async def __load_letters(self, pattern: str) -> Set[Tuple[uuid.UUID, uuid.UUID, str]]:
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
            fields=lambda name, entry: (entry.owner, entry.name)
        )
        return set(zip(result.keys(), result.values()))

    async def load_inbox(self) -> Set[Tuple[uuid.UUID, uuid.UUID, str]]:
        """Load envelopes from the inbox."""
        return await self.__load_letters(self.PATH_INBOX[0] + "*")
        """
        doc_list = await self.facade.storage.vault.search_docs(
            self.facade.data.portfolio.entity.id, MailboxAPI.INBOX + "/*", limit=200
        )
        result = Glue.doc_validate_report(doc_list, Envelope)
        return result
        """

    async def load_outbox(self) -> Set[Tuple[uuid.UUID, uuid.UUID, str]]:
        """Load letters from outbox folder."""
        return await self.__load_letters(self.PATH_OUTBOX[0] + "*")
        """
        doclist = await self.facade.storage.vault.search_docs(
            path=MailboxAPI.OUTBOX + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Envelope)
        return result
        """

    async def load_read(self) -> Set[Tuple[uuid.UUID, uuid.UUID, str]]:
        """Load read folder from the messages store."""
        return await self.__load_letters(self.PATH_READ[0] + "*")
        """
        doclist = await self.facade.storage.vault.search_docs(
            self.facade.data.portfolio.entity.id, MailboxAPI.READ + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Mail)
        return result
        """

    async def load_drafts(self) -> Set[Tuple[uuid.UUID, uuid.UUID, str]]:
        """Load read folder from the messages store."""
        return await self.__load_letters(self.PATH_DRAFT[0] + "*")
        """
        doclist = await self.facade.storage.vault.search_docs(
            path=MailboxAPI.DRAFT + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Mail, False)
        return result
        """

    async def load_trash(self) -> Set[Tuple[uuid.UUID, uuid.UUID, str]]:
        """Load read folder from the messages store."""
        return await self.__load_letters(self.PATH_TRASH[0] + "*")
        """
        doclist = await self.facade.storage.vault.search_docs(
            path=MailboxAPI.DRAFT + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Mail, False)
        return result
        """

    async def load_sent(self) -> Set[Tuple[uuid.UUID, uuid.UUID, str]]:
        """Load read folder from the messages store."""
        return await self.__load_letters(self.PATH_SENT[0] + "*")
        """
        doclist = await self.facade.storage.vault.search_docs(
            path=MailboxAPI.DRAFT + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Mail, False)
        return result
        """

    async def __info_mail(self, dirname: str, name: str) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        """Get info about a mail.

        Args:
            dirname (str):
                Which folder in the mailbox
            name (str):
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

        letter = await self.facade.storage.vault.archive.load(os.path.join(dirname, name))
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

    async def __info_draft(self, dirname: str, name: str) -> Tuple[
        bool, uuid.UUID, str, str, uuid.UUID, int]:
        """Get info about a draft.

        Args:
            dirname (str):
                Which folder in the mailbox
            name (str):
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

        letter = await self.facade.storage.vault.archive.load(os.path.join(dirname, name))
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

    async def __info_inbox_envelope(self, dirname: str, name: str) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime, bool, bool, bool]:
        """Get info about an envelope.

        Args:
            dirname (str):
                Which folder in the mailbox
            name (str):
                File name of message

        Returns (Tuple[bool, str, datetime.datetime]):
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

        letter = await self.facade.storage.vault.archive.load(os.path.join(dirname, name))
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

    async def __info_outbox_envelope(self, dirname: str, name: str) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime]:
        """Get info about an envelope.

        Args:
            dirname (str):
                Which folder in the mailbox
            name (str):
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

        letter = await self.facade.storage.vault.archive.load(os.path.join(dirname, name))
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

    async def get_info_inbox(self, name: str) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime, bool, bool, bool]:
        return await self.__info_inbox_envelope(self.PATH_INBOX[0], name)

    async def get_info_outbox(self, name: str) -> Tuple[
        bool, uuid.UUID, str, datetime.datetime]:
        return await self.__info_outbox_envelope(self.PATH_INBOX[0], name)

    async def get_info_read(self, name: str) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        return await self.__info_mail(self.PATH_READ[0], name)

    async def get_info_draft(self, name: str) -> Tuple[
        bool, uuid.UUID, str, str, uuid.UUID, int]:
        return await self.__info_draft(self.PATH_DRAFT[0], name)

    async def get_info_trash(self, name: str) -> Tuple[
        bool, uuid.UUID, str, str, datetime.datetime, uuid.UUID, int]:
        return await self.__info_mail(self.PATH_TRASH[0], name)

    async def mail_to_inbox(
        self, envelopes: Envelope
    ) -> (bool, Set[Envelope], bool):
        """Import envelope to inbox. Check owner and then validate."""
        reject = set()
        save_list = list()

        for envelope in envelopes:
            envelope = EnvelopePolicy.receive(self.facade.data.portfolio, envelope)
            if not envelope:
                reject.add(envelope)
                continue

            save_list.append(
                self.facade.storage.vault.save(
                    DOCUMENT_PATH[envelope.type].format(
                        dir=MailboxAPI.INBOX, file=envelope.id
                    ),
                    envelope,
                )
            )

        result = await asyncio.gather(*save_list, return_exceptions=True)
        return True, reject, result

    async def load_envelope(self, envelope_id: uuid.UUID) -> Envelope:
        """Load specific envelope from the inbox."""
        return await self._load_doc(envelope_id, DocType.COM_ENVELOPE, MailboxAPI.INBOX, Envelope)

    async def load_message(self, message_id: uuid.UUID) -> Mail:
        """Load specific message from the read folder."""
        return await self._load_doc(message_id, DocType.COM_MAIL, MailboxAPI.READ, Mail)

    async def _load_doc(self, doc_id: uuid.UUID, doc_type_num, box_dir, doc_class) -> Any:
        doc_list = await self.facade.storage.vault.search_docs(
            path=DOCUMENT_PATH[doc_type_num].format(
                dir=box_dir, file=doc_id
            ),
            limit=1,
        )
        if not doc_list:
            return None
        result = Glue.doc_validate_report(doc_list, doc_class)
        if isinstance(result[0][1], Exception):
            return None

        return result[0][0]

    async def store_letter(self, envelope: Envelope, message: Message) -> bool:
        """
        Save a related envelope and message for later complaint.

        The calling function is responsible for opening the envelope and
        applying the necessary policies.
        """
        if envelope.issuer != message.issuer:
            raise ValueError("Issuer mismatch between Envelope and Message")
        if envelope.owner != message.owner:
            raise ValueError("Owner mismatch between Envelope and Message")
        if abs(envelope.posted - message.posted) > datetime.timedelta(
            seconds=60
        ):
            raise ValueError("Envelope and message timestamp mismatch.")

        letter = StoredLetter(
            nd={
                "id": message.id,
                "issuer": self.facade.data.portfolio.entity.id,
                "envelope": envelope,
                "message": message,
            }
        )
        letter = Crypto.sign(letter, self.facade.data.portfolio)
        letter.validate()

        result = await self.facade.storage.vault.save(
            DOCUMENT_PATH[DocType.CACHED_MSG].format(
                dir=MailboxAPI.CACHE, file=letter.id
            ),
            letter,
        )
        if isinstance(result, Exception):
            raise result

        result = await self.facade.storage.vault.delete(
            DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=MailboxAPI.INBOX, file=envelope.id
            )
        )
        if isinstance(result, Exception):
            raise result

        return True

    async def save_read(self, message: Mail):
        """Save a message as read in the read message folder."""
        result = await self.facade.storage.vault.save(
            DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=MailboxAPI.READ, file=message.id
            ),
            message,
        )
        if isinstance(result, Exception):
            raise result
        return True

    async def save_outbox(self, envelope: Envelope):
        """Save a message to outbox folder to be sent."""
        result = await self.__vault.save(
            DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=MailboxAPI.OUTBOX, file=envelope.id
            ),
            envelope,
        )
        if isinstance(result, Exception):
            raise result
        return True

    async def save_sent(self, message: Mail):
        """Save a message to sent folder for archiving."""
        result = await self.facade.storage.vault.save(
            DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=MailboxAPI.SENT, file=message.id
            ),
            message,
        )
        if isinstance(result, Exception):
            raise result
        return True

    async def save_draft(self, message: Mail):
        """Save a message to draft folder for archiving."""
        result = await self.facade.storage.vault.save(
            DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=MailboxAPI.DRAFT, file=message.id
            ),
            message,
        )
        if isinstance(result, Exception):
            raise result
        return True

    async def import_envelope(self, envelope: Envelope):
        """Imports an envelope to inbox."""
        result = await self.facade.storage.vault.save(
            DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=MailboxAPI.PATH_INBOX[0], file=envelope.id
            ),
            envelope,
        )
        if isinstance(result, Exception):
            raise result
        return True
