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
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.envelope import Envelope, Header
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.envelope.policy import EnvelopePolicy
from angelos.portfolio.policy import DocumentPolicy


# TODO: Make an overhaul


class ReceiveEnvelope(DocumentPolicy, EnvelopePolicy, PolicyPerformer, PolicyMixin):
    def __init__(self):
        super().__init__()

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None

    def apply(self) -> bool:
        """Receive the envelope when it reaches its final domain."""
        if not self._document.validate():
            raise PolicyException()

        if self._document.owner != self._portfolio.entity.id:
            raise PolicyException()

        self._add_header(self._portfolio, self._document, Header.Op.RECEIVE)
        return True

    @policy(b'I', 0, "Envelope:Receive")
    def perform(self, recipient: PrivatePortfolio, envelope: Envelope) -> Envelope:
        self._portfolio = recipient
        self._document = envelope
        self._applier()
        return self._document
