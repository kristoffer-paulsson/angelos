# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade mail API."""
import asyncio
from typing import List, Set

from ..policy import PrivatePortfolio, EnvelopePolicy, DOCUMENT_PATH
from ..document import Envelope
from ..archive.vault import Vault
from ..archive.helper import Glue


class Mail:
    """An interface class to be placed on the facade."""

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
                    dir=Vault.INBOX, file=envelope.id), envelope))

        result = await asyncio.gather(*savelist, return_exceptions=True)
        return True, reject, result

    async def load_inbox(self) -> List[Envelope]:
        """Load envelopes from the inbox."""
        doclist = await self.__vault.search(
            self.__portfolio.entity.id, Vault.INBOX + '*', limit=200)
        result = Glue.doc_validate_report(doclist, Envelope)
        return result
