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
from angelos.document.domain import Domain
from angelos.portfolio.collection import Portfolio, PrivatePortfolio
from angelos.portfolio.policy import DocumentPolicy, UpdatablePolicy


class BaseValidateDomain(PolicyValidator):
    """Initialize the updated entity validator."""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._document = None
        self._former = None

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None
        self._former = None


class ValidateDomainMixin(DocumentPolicy, UpdatablePolicy, PolicyMixin):
    """Logic for validating and updated Entity for a Portfolio."""

    def apply(self) -> bool:
        """Perform logic to validate updated domain with current."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_fields_unchanged() if self._former else True
        ]):
            raise PolicyException()
        return True


class ValidateDomain(BaseValidateDomain, ValidateDomainMixin):
    """Validate updated domain."""

    @policy(b'I', 0, "Domain:ValidatePrivatePortfolio")
    def validate(self, portfolio: PrivatePortfolio, domain: Domain) -> bool:
        """Perform validation of updated domain for portfolio."""
        self._portfolio = portfolio
        self._document = domain
        self._former = portfolio.get_id(domain)
        self._applier()
        return True