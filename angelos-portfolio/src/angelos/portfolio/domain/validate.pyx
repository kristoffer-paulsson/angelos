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
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.policy import UpdatablePolicy


class ValidateDomain(UpdatablePolicy, PolicyValidator, PolicyMixin):
    """Validate updated domain."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None
        self._former = None

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

    @policy(b'I', 0, "Domain:ValidatePrivate")
    def validate(self, portfolio: PrivatePortfolio, domain: Domain) -> bool:
        """Perform validation of updated domain for portfolio."""
        self._portfolio = portfolio
        self._document = domain
        self._former = portfolio.get_id(domain)
        self._applier()
        return True