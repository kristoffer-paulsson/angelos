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
"""Operations regarding mail, messages and envelope handling."""
import uuid

from angelos.document.types import MessageT
from angelos.lib.operation.operation import Operation
from angelos.lib.policy.message import EnvelopePolicy
from angelos.lib.policy.portfolio import PGroup

from angelos.lib.facade.facade import Facade


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
