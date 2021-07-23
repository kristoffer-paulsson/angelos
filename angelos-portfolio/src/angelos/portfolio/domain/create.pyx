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
"""Creating new domain document for new portfolio."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Domain
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, FrozenPortfolioError
from angelos.portfolio.policy import DocumentPolicy


class DomainCreateException(RuntimeError):
    """Problems with the process that is not policy."""
    DOMAIN_IN_PORTFOLIO = ("Domain document already present in portfolio.", 100)


class CreateDomain(DocumentPolicy, PolicyPerformer, PolicyMixin):
    """Generate domain document and add to private portfolio."""

    def _setup(self):
        self._document = None

    def _clean(self):
        pass

    def apply(self) -> bool:
        """Perform logic to create a new domain with portfolio."""
        if self._portfolio.is_frozen():
            raise FrozenPortfolioError()

        if self._portfolio.domain:
            raise DomainCreateException(*DomainCreateException.DOMAIN_IN_PORTFOLIO)

        self._document = Domain(nd={"issuer": self._portfolio.entity.id})
        self._document = Crypto.sign(self._document, self._portfolio)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify()
        ]):
            raise PolicyException()

        self._add()

    @policy(b'I', 0, "Domain:Create")
    def perform(self, portfolio: PrivatePortfolio) -> Domain:
        """Perform building of person portfolio."""
        self._portfolio = portfolio
        self._applier()
        return self._document
