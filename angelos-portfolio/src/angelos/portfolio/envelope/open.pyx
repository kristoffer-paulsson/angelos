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
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.envelope import Envelope
from angelos.document.messages import Message
from angelos.document.utils import Helper as DocumentHelper
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, Portfolio
from angelos.portfolio.envelope.policy import EnvelopePolicy
from angelos.portfolio.policy import IssuePolicy


# TODO: Make an overhaul


class OpenEnvelope(IssuePolicy, EnvelopePolicy, PolicyPerformer, PolicyMixin):
    def __init__(self):
        super().__init__()

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._owner = None

    def apply(self) -> bool:
        """Open an envelope and unveil the message."""
        if not Crypto.verify(self._document, self._owner, exclude=["header"]):
            raise PolicyException()

        if not self._document.validate():
            raise PolicyException()

        self._document = DocumentHelper.deserialize(
            Crypto.unveil(self._document.message, self._portfolio, self._owner)
        )

        if not Crypto.verify(self._document, self._owner):
            raise PolicyException()

        if not self._document.validate():
            raise PolicyException()

        return True

    @policy(b'I', 0, "Envelope:Open")
    def perform(self, recipient: PrivatePortfolio, sender: Portfolio, envelope: Envelope) -> Message:
        self._portfolio = recipient
        self._owner = sender
        self._document = envelope
        self._applier()
        return self._document