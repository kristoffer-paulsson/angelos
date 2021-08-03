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
"""Dummy data generation utilities."""
import random

import libnacl
from libangelos.const import Const
from angelos.document.document import DocType
from angelos.common.facade.facade import Facade
from libangelos.operation.setup import SetupChurchOperation, SetupMinistryOperation
from libangelos.operation.setup import SetupPersonOperation
from libangelos.policy.domain import NetworkPolicy
from angelos.common.policy.message import MessagePolicy, EnvelopePolicy
from angelos.common.policy.portfolio import Portfolio, DOCUMENT_PATH
from libangelos.policy.verify import StatementPolicy

from .support import Generate, run_async


class DummyPolicy:
    """Policy to generate dummy data according to scenarios."""

    @run_async
    async def make_mail(self, facade: Facade, sender: Portfolio, inbox: bool=True, num: int=1):
        """Generate X number of mails from sender within facade.

        Args:
            facade (Facade):
                Facade to send random dummy mails to .
            sender (Portfolio):
                Senders portfolio.
            num (int):
                Numbers of mail to generate.

        """
        for _ in range(num):
            envelope = EnvelopePolicy.wrap(
                sender,
                facade.data.portfolio,
                MessagePolicy.mail(sender, facade.data.portfolio).message(
                    Generate.filename(postfix="."),
                    Generate.lipsum_sentence().decode(),
                ).done(),
            )
            if inbox:
                await facade.api.mailbox.import_envelope(envelope)
            else:
                filename = DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                    dir="/", file=envelope.id
                )
                await facade.api.mail.save(filename, envelope)