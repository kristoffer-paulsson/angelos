# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade mail API."""
import asyncio
import uuid
from typing import List, Set

from ..policy import PrivatePortfolio, EnvelopePolicy, DOCUMENT_PATH
from ..document import Envelope, Message, DocType
from ..archive.vault import Vault
from ..archive.helper import Glue


class Mail:
    """An interface class to be placed on the facade."""

    INBOX = '/messages/inbox/'
    READ = '/messages/read/'

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

    async def load_message(self, message_id: uuid.UUID) -> Message:
        """Load specific message from the read folder."""
        doclist = await self.__vault.search(
            path=DOCUMENT_PATH[DocType.COM_MAIL].format(
                dir=Mail.READ, file=message_id), limit=1)
        if not doclist:
            return None
        result = Glue.doc_validate_report(doclist, Message)
        if isinstance(result[0][1], Exception):
            return None

        return result[0][0]
