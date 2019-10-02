# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Operations regarding mail, messages and envelope handling.
"""
import uuid

from .operation import Operation
from ..facade.facade import Facade
from ..policy import PGroup, EnvelopePolicy
from ..document import Message


class MailOperation(Operation):
    @staticmethod
    async def open_envelope(facade: Facade, envelope_id: uuid.UUID) -> Message:
        """Open an envelope and verify its content according to policies."""
        envelope = await facade.mail.load_envelope(envelope_id)
        sender = await facade.load_portfolio(envelope.issuer, PGroup.VERIFIER)
        message = EnvelopePolicy.open(facade.portfolio, sender, envelope)
        await facade.mail.store_letter(envelope, message)
        await facade.mail.save_read(message)
        return message, sender
