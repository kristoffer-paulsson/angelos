# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade mail API."""
import asyncio
import datetime
import uuid
from typing import List, Set

from ..policy import PrivatePortfolio, EnvelopePolicy, DOCUMENT_PATH, Crypto
from ..document import Envelope, Mail, Message, DocType, StoredLetter
from ..archive.vault import Vault
from ..archive.helper import Glue


class Mail:
    """An interface class to be placed on the facade."""

    INBOX = '/messages/inbox/'
    READ = '/messages/read/'
    CACHE = '/cache/msg/'

    def __init__(self, portfolio: PrivatePortfolio, vault: Vault):
        """Init mail interface."""
        self.__portfolio = portfolio
        self.__vault = vault

    async def mail_to_inbox(
            self, envelopes: Envelope) -> (bool, Set[Envelope], bool):
        """Import envelope to inbox. Check owner and then validate."""
        reject = set()
        savelist = []

        for envelope in envelopes:
            envelope = EnvelopePolicy.receive(self.__portfolio, envelope)
            if not envelope:
                reject.add(envelope)
                continue

            savelist.append(self.__vault.save(
                DOCUMENT_PATH[envelope.type].format(
                    dir=Mail.INBOX, file=envelope.id), envelope))

        result = await asyncio.gather(*savelist, return_exceptions=True)
        return True, reject, result

    async def load_inbox(self) -> List[Envelope]:
        """Load envelopes from the inbox."""
        doclist = await self.__vault.search(
            self.__portfolio.entity.id, Mail.INBOX + '*', limit=200)
        result = Glue.doc_validate_report(doclist, Envelope)
        return result

    async def load_envelope(self, envelope_id: uuid.UUID) -> Envelope:
        """Load specific envelope from the inbox."""
        doclist = await self.__vault.search(
            path=DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=Mail.INBOX, file=envelope_id), limit=1)
        if not doclist:
            return None
        result = Glue.doc_validate_report(doclist, Envelope)
        if isinstance(result[0][1], Exception):
            return None

        return result[0][0]

    async def load_message(self, message_id: uuid.UUID) -> Mail:
        """Load specific message from the read folder."""
        doclist = await self.__vault.search(
            path=DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=Mail.READ, file=message_id), limit=1)
        if not doclist:
            return None
        result = Glue.doc_validate_report(doclist, Mail)
        if isinstance(result[0][1], Exception):
            return None

        return result[0][0]

    async def store_letter(
            self, envelope: Envelope, message: Message) -> bool:
        """
        Save a related envelope and message for later complaint.

        The calling function is responsible for opening the envelope and
        applying the necessary policies.
        """
        if envelope.issuer != message.issuer:
            raise ValueError('Issuer mismatch between Envelope and Message')
        if envelope.owner != message.owner:
            raise ValueError('Owner mismatch between Envelope and Message')
        if abs(envelope.posted - message.posted
               ) > datetime.timedelta(seconds=60):
            raise ValueError('Envelope and message timestamp mismatch.')

        letter = StoredLetter(nd={
            'id': message.id,
            'issuer': self.__portfolio.entity.id,
            'envelope': envelope,
            'message': message
        })
        letter = Crypto.sign(letter, self.__portfolio)
        letter.validate()

        result = await self.__vault.save(
            DOCUMENT_PATH[DocType.CACHED_MSG].format(
                dir=Mail.CACHE, file=letter.id), letter)
        if isinstance(result, Exception):
            raise result

        result = await self.__vault.delete(
            DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir=Mail.INBOX, file=envelope.id))
        if isinstance(result, Exception):
            raise result

        return True

    async def save_read(self, message: Mail):
        """Save a message as read in the read message folder."""
        await self.__vault.save(DOCUMENT_PATH[DocType.COM_MAIL].format(
            dir=Mail.READ, file=message.id), message)
        return True

    async def load_read(self) -> List[Mail]:
        """Load read folder from the messages store."""
        doclist = await self.__vault.search(
            self.__portfolio.entity.id, Mail.READ + '*', limit=100)
        result = Glue.doc_validate_report(doclist, Mail)
        return result
