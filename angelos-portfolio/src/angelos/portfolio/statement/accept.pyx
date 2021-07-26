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
from angelos.document.statements import Trusted, Verified, Revoked
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.policy import DocumentPolicy


class AcceptStatementMixin(DocumentPolicy, PolicyMixin):
    """Logic for validating a statement for a Portfolio."""

    def _setup(self):
        pass

    def _clean(self):
        pass

    def apply(self) -> bool:
        """Perform logic to validate a statement."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify()
        ]):
            raise PolicyException()

        self._add()
        return True


class AcceptTrustedStatement(AcceptStatementMixin, PolicyValidator):
    """Validate a trusted statement."""

    @policy(b'I', 0, "Trusted:Validate")
    def validate(self, portfolio: Portfolio, trusted: Trusted) -> bool:
        """Perform validation of trusted statement for portfolio."""
        self._portfolio = portfolio
        self._document = trusted
        self._applier()
        return True


class AcceptVerifiedStatement(AcceptStatementMixin, PolicyValidator):
    """Validate a statement."""

    @policy(b'I', 0, "Verified:Validate")
    def validate(self, portfolio: Portfolio, verified: Verified) -> bool:
        """Perform validation of verified statement for portfolio."""
        self._portfolio = portfolio
        self._document = verified
        self._applier()
        return True


class AcceptRevokedStatement(AcceptStatementMixin, PolicyValidator):
    """Validate a statement."""

    @policy(b'I', 0, "Revoked:Validate")
    def validate(self, portfolio: Portfolio, revoked: Revoked) -> bool:
        """Perform validation of revoked statement for portfolio."""
        self._portfolio = portfolio
        self._document = revoked
        self._applier()
        return True