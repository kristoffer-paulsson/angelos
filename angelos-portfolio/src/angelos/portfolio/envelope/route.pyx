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
from angelos.common.policy import policy, PolicyPerformer, PolicyMixin
from angelos.document.envelope import Envelope, Header
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.envelope.policy import EnvelopePolicy
from angelos.portfolio.policy import DocumentPolicy


# TODO: Make an overhaul


class RouteEnvelope(DocumentPolicy, EnvelopePolicy, PolicyPerformer, PolicyMixin):
    def __init__(self):
        super().__init__()

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None

    def apply(self) -> bool:
        """Sign an envelope header."""
        if self._document.header[-1].op == Header.Op.RECEIVE:
            raise RuntimeError("Envelope already received.")

        self._add_header(self._portfolio, self._document, Header.Op.ROUTE)
        return True

    @policy(b'I', 0, "Envelope:Route")
    def perform(self, router: PrivatePortfolio, envelope: Envelope) -> Envelope:
        self._portfolio = router
        self._document = envelope
        self._applier()
        return self._document

