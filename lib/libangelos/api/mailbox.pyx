# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Facade mail API."""
import asyncio
import datetime
import uuid
from typing import List, Set, Any

from libangelos.api.api import ApiFacadeExtension
from libangelos.document.document import DocType
from libangelos.document.envelope import Envelope
from libangelos.document.messages import Message, Mail
from libangelos.document.misc import StoredLetter
from libangelos.facade.base import BaseFacade
from libangelos.helper import Glue
from libangelos.policy.crypto import Crypto
from libangelos.policy.message import EnvelopePolicy
from libangelos.policy.portfolio import DOCUMENT_PATH
from libangelos.misc import LazyAttribute


class MailboxAPI(ApiFacadeExtension):
    """An interface class to be placed on the facade."""

    ATTRIBUTE = ("mailbox",)

    INBOX = "/messages/inbox"
    READ = "/messages/read"
    CACHE = "/cache/msg"
    OUTBOX = "/messages/outbox"
    SENT = "/messages/sent"
    DRAFT = "/messages/drafts"
    TRASH = "/messages/trash"

    def __init__(self, facade: BaseFacade):
        """Initialize the Mail."""
        ApiFacadeExtension.__init__(self, facade)

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

    async def load_inbox(self) -> List[Envelope]:
        """Load envelopes from the inbox."""
        doc_list = await self.facade.storage.vault.search(
            self.facade.data.portfolio.entity.id, MailboxAPI.INBOX + "/*", limit=200
        )
        result = Glue.doc_validate_report(doc_list, Envelope)
        return result

    async def load_envelope(self, envelope_id: uuid.UUID) -> Envelope:
        """Load specific envelope from the inbox."""
        return await self._load_doc(envelope_id, DocType.COM_ENVELOPE, MailboxAPI.INBOX, Envelope)

    async def load_message(self, message_id: uuid.UUID) -> Mail:
        """Load specific message from the read folder."""
        return await self._load_doc(message_id, DocType.COM_MAIL, MailboxAPI.READ, Mail)

    async def _load_doc(self, doc_id: uuid.UUID, doc_type_num, box_dir, doc_class) -> Any:
        doc_list = await self.facade.storage.vault.search(
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

    async def load_read(self) -> List[Mail]:
        """Load read folder from the messages store."""
        doclist = await self.facade.storage.vault.search(
            self.facade.data.portfolio.entity.id, MailboxAPI.READ + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Mail)
        return result

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

    async def load_outbox(self) -> List[Envelope]:
        """Load letters from outbox folder."""
        doclist = await self.facade.storage.vault.search(
            path=MailboxAPI.OUTBOX + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Envelope)
        return result

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

    async def load_drafts(self) -> List[Mail]:
        """Load read folder from the messages store."""
        doclist = await self.facade.storage.vault.search(
            path=MailboxAPI.DRAFT + "/*", limit=100
        )
        result = Glue.doc_validate_report(doclist, Mail, False)
        return result

    async def import_envelope(self, envelope: Envelope):
        """Imports an envelope to inbox."""
        result = await self.facade.storage.vault.save(
            DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=MailboxAPI.INBOX, file=envelope.id
            ),
            envelope,
        )
        if isinstance(result, Exception):
            raise result
        return True
