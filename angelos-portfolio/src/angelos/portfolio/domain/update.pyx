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
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException, PolicyValidator
from angelos.document.domain import Domain
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, FrozenPortfolioError


class DomainUpdateException(RuntimeError):
    """Problems with the process that is not policy."""
    DOMAIN_NOT_IN_PORTFOLIO = ("Domain document not present in portfolio.", 100)


class BaseUpdateDomain(PolicyPerformer):
    """Initialize the domain updater"""
    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._domain = None

    def _setup(self):
        self._domain = None

    def _clean(self):
        self._portfolio = None


class UpdateDomainMixin(PolicyMixin):
    """Logic for updating Domain for a PrivatePortfolio."""

    def apply(self) -> bool:
        """Perform logic to update a domain with portfolio."""
        if not self._portfolio.domain:
            raise DomainUpdateException(*DomainUpdateException.DOMAIN_NOT_IN_PORTFOLIO)

        self._domain = self._portfolio.domain
        self._domain.renew()
        Crypto.sign(self._domain, self._portfolio)
        self._domain.validate()


class UpdateDomain(BaseUpdateDomain, UpdateDomainMixin):
    """Update domain document for private portfolio."""

    @policy(b'I', 0, "Domain:Update")
    def perform(self, portfolio: PrivatePortfolio) -> Domain:
        """Perform domain update of private portfolio."""
        self._portfolio = portfolio
        self._applier()
        return self._domain
