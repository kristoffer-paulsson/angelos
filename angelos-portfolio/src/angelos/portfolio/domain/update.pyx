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
"""Updating a domain document for a portfolio."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Domain
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.policy import UpdatablePolicy


class DomainUpdateException(RuntimeError):
    """Problems with the process that is not policy."""
    DOMAIN_NOT_IN_PORTFOLIO = ("Domain document not present in portfolio.", 100)


class UpdateDomain(UpdatablePolicy, PolicyPerformer, PolicyMixin):
    """Update domain document for private portfolio."""

    def _setup(self):
        self._document = None

    def _clean(self):
        self._portfolio = None

    def apply(self) -> bool:
        """Perform logic to update a domain with portfolio."""
        if not self._portfolio.domain:
            raise DomainUpdateException(*DomainUpdateException.DOMAIN_NOT_IN_PORTFOLIO)

        self._former = self._portfolio.domain
        self._document = self._portfolio.domain
        self._document.renew()
        Crypto.sign(self._document, self._portfolio)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_fields_unchanged() if self._former else True
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Domain:Update")
    def perform(self, portfolio: PrivatePortfolio) -> Domain:
        """Perform domain update of private portfolio."""
        self._portfolio = portfolio
        self._applier()
        return self._document
