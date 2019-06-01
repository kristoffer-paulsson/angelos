# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Facade mail API."""
from ..policy import PrivatePortfolio, EnvelopePolicy, DOCUMENT_PATH
from ..document import Envelope
from ..archive.vault import Vault


class Mail:
    """An interface class to be placed on the facade."""

    def __init__(self, portfolio: PrivatePortfolio, vault: Vault):
        """Init mail interface."""
        self.__portfolio = portfolio
        self.__vault = vault

    def mail_to_inbox(self, envelope: Envelope) -> bool:
        """Import envelope to inbox. Check owner and then validate."""
        envelope = EnvelopePolicy.receive(self.__portfolio, envelope)
        if not envelope:
            return False

        self.__vault.save(
            DOCUMENT_PATH[envelope.type].format(
                Vault.INBOX, envelope.id), envelope)
        return True

    def load_inbox(self) -> Envelope:
        """Load envelopes from the inbox."""
        pass
