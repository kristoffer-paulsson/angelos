# cython: language_level=3
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
"""Creating new entity portfolio for Person, Ministry and Church including Keys and PrivateKeys documents."""
from angelos.common.policy import PolicyMixin, policy, PolicyException, PolicyValidator
from angelos.document.messages import Message
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.policy import IssuePolicy


class ValidateMessage(IssuePolicy, PolicyValidator, PolicyMixin):
    """Validate network."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._owner = None
        self._document = None

    @policy(b'I', 0)
    def _check_message_sender(self) -> bool:
        if self._document.issuer != self._owner.entity.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_envelope_recipient(self) -> bool:
        if self._document.owner != self._portfolio.entity.id:
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Validate a message addressed to the internal portfolio."""
        if not all([
            self._check_message_sender(),
            self._check_message_recipient(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify()
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Message:Validate")
    def validate(self, portfolio: Portfolio, sender: Portfolio, message: Message) -> bool:
        self._portfolio = portfolio
        self._owner = sender
        self._document = message
        self._applier()
        return True