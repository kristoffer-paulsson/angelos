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
from angelos.document.statements import Trusted, Verified, Revoked
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.policy import DocumentPolicy


class BaseValidateStatement(PolicyValidator):
    """Initialize the statement validator"""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._document = None

    def _setup(self):
        pass

    def _clean(self):
        pass


class ValidateStatementMixin(DocumentPolicy, PolicyMixin):
    """Logic for validating a statement for a Portfolio."""

    def apply(self) -> bool:
        """Perform logic to validate a statement."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify()
        ]):
            raise PolicyException()
        return True


class ValidateTrustedStatement(BaseValidateStatement, ValidateStatementMixin):
    """Validate a trusted statement."""

    @policy(b'I', 0, "Trusted:ValidatePortfolio")
    def validate(self, portfolio: Portfolio, trusted: Trusted) -> bool:
        """Perform validation of trusted statement for portfolio."""
        self._portfolio = portfolio
        self._document = trusted
        self._applier()
        return True


class ValidateVerifiedStatement(BaseValidateStatement, ValidateStatementMixin):
    """Validate a statement."""

    @policy(b'I', 0, "Verified:ValidatePortfolio")
    def validate(self, portfolio: Portfolio, verified: Verified) -> bool:
        """Perform validation of trusted statement for portfolio."""
        self._portfolio = portfolio
        self._document = verified
        self._applier()
        return True


class ValidateRevokedStatement(BaseValidateStatement, ValidateStatementMixin):
    """Validate a statement."""

    @policy(b'I', 0, "Revoked:ValidatePortfolio")
    def validate(self, portfolio: Portfolio, revoked: Revoked) -> bool:
        """Perform validation of revoked statement for portfolio."""
        self._portfolio = portfolio
        self._statement = revoked
        self._applier()
        return True