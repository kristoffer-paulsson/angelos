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
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import Portfolio


class BaseAcceptUpdatedDomain(PolicyValidator):
    """Initialize the updated entity validator."""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._domain = None

    def _setup(self):
        pass

    def _clean(self):
        self._domain = None


class AcceptUpdatedDomainMixin(PolicyMixin):
    """Logic for validating and updated Entity for a Portfolio."""

    @policy(b'I', 0)
    def _check_domain_issuer(self) -> bool:
        if self._domain.issuer != self._portfolio.entity.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_domain_expired(self) -> bool:
        if self._domain.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_domain_valid(self) -> bool:
        if not self._domain.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_domain_verify(self) -> bool:
        if not Crypto.verify(self._domain, self._portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_fields_unchanged(self) -> bool:
        unchanged = set(self._domain.fields()) - set(["signature", "expires", "updated"])
        same = list()
        for name in unchanged:
            same.append(getattr(self._domain, name) == getattr(self._portfolio.domain, name))

        if not all(same):
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate updated domain with current."""
        if not all([
            self._check_domain_issuer(),
            self._check_domain_expired(),
            self._check_domain_valid(),
            self._check_domain_verify(),
            self._check_fields_unchanged()
        ]):
            raise PolicyException()

        docs = self._portfolio.filter({self._portfolio.domain}) | {self._domain}
        self._portfolio.__init__(docs)
        return True


class AcceptUpdatedDomain(BaseAcceptUpdatedDomain, AcceptUpdatedDomainMixin):
    """Validate updated domain."""

    @policy(b'I', 0, "Domain:AcceptUpdate")
    def validate(self, portfolio: Portfolio, domain: Domain) -> bool:
        """Perform validation of updated domain for portfolio."""
        self._portfolio = portfolio
        self._domain = domain
        self._applier()
        return True