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
"""Creating new domain document for new portfolio."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Domain
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, FrozenPortfolioError


class DomainCreateException(RuntimeError):
    """Problems with the process that is not policy."""
    DOMAIN_IN_PORTFOLIO = ("Domain document already present in portfolio.", 100)


class BaseCreateDomain(PolicyPerformer):
    """Initialize the domain generator"""
    def __init__(self):
        super().__init__()
        self._portfolio = None

    def _setup(self):
        pass

    def _clean(self):
        pass


class CreateDomainMixin(PolicyMixin):
    """Logic for generating Domain for a new PrivatePortfolio."""

    def apply(self) -> bool:
        """Perform logic to create a new domain with portfolio."""
        if self._portfolio.is_frozen():
            raise FrozenPortfolioError()

        if self._portfolio.domain:
            raise DomainCreateException(*DomainCreateException.DOMAIN_IN_PORTFOLIO)

        domain = Domain(nd={"issuer": self._portfolio.entity.id})

        domain = Crypto.sign(domain, self._portfolio)
        domain.validate()
        self._portfolio.documents().add(domain)


class CreateDomain(BaseCreateDomain, CreateDomainMixin):
    """Generate domain document and add to private portfolio."""

    @policy(b'I', 0, "Domain:Create")
    def perform(self, portfolio: PrivatePortfolio) -> bool:
        """Perform building of person portfolio."""
        self._portfolio = portfolio
        self._applier()
        return True
