# cython: language_level=3, linetrace=True
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
import datetime

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.envelope import Envelope, Header, ENVELOPE_EXPIRY_PERIOD
from angelos.document.messages import Message
from angelos.document.utils import Helper as DocumentHelper
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, Portfolio
from angelos.portfolio.envelope.policy import EnvelopePolicy
from angelos.portfolio.policy import IssuePolicy


# TODO: Make an overhaul


class WrapEnvelope(IssuePolicy, EnvelopePolicy, PolicyPerformer, PolicyMixin):
    def __init__(self):
        super().__init__()

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._owner = None

    def apply(self) -> bool:
        """Wrap a message in an envelope."""
        Crypto.verify(self._document, self._portfolio)
        self._document.validate()

        if not (
            (self._document.issuer == self._portfolio.entity.id)
            and (self._document.owner == self._owner.entity.id)
        ):
            raise PolicyException()

        self._document = Envelope(nd={
            "issuer": self._document.issuer,
            "owner": self._document.owner,
            "message": Crypto.conceal(
                DocumentHelper.serialize(self._document), self._portfolio, self._owner
            ),
            "expires": datetime.date.today() + datetime.timedelta(ENVELOPE_EXPIRY_PERIOD),
            "posted": datetime.datetime.utcnow(),
            "header": [],
        })

        envelope = Crypto.sign(self._document, self._portfolio, exclude=["header"])

        self._add_header(self._portfolio, self._document, Header.Op.SEND)
        self._document.validate()

        return True

    @policy(b'I', 0, "Envelope:Wrap")
    def perform(self, sender: PrivatePortfolio, recipient: Portfolio, message: Message) -> Envelope:
        self._portfolio = sender
        self._owner = recipient
        self._document = message
        self._applier()
        return self._document





