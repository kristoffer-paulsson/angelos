# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Operations regarding mail, messages and envelope handling."""
import uuid

from libangelos.operation.operation import Operation
from libangelos.facade.facade import Facade
from libangelos.policy.portfolio import PGroup
from libangelos.policy.message import EnvelopePolicy
from libangelos.document.types import MessageT


class MailOperation(Operation):
    @staticmethod
    async def open_envelope(
        facade: Facade, envelope_id: uuid.UUID
    ) -> MessageT:
        """Open an envelope and verify its content according to policies."""
        envelope = await facade.mail.load_envelope(envelope_id)
        sender = await facade.load_portfolio(envelope.issuer, PGroup.VERIFIER)
        message = EnvelopePolicy.open(facade.portfolio, sender, envelope)
        await facade.mail.store_letter(envelope, message)
        await facade.mail.save_read(message)
        return message, sender
