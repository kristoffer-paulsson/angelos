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
from angelos.common.policy import PolicyValidator, PolicyMixin, policy, PolicyException
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.statement.validate import ValidateTrustedStatement


class ValidateTrust(PolicyValidator, PolicyMixin):
    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._owner = None
        self._validator = ValidateTrustedStatement()

    def _setup(self):
        pass

    def _clean(self):
        pass

    @policy(b'I', 0)
    def _check_established_trust(self) -> bool:
        if not any([self._validator.validate(self._portfolio, doc) for doc in self._owner.get_issuer(
                self._owner.get_not_expired(self._owner.trusted_owner), self._portfolio.entity.id)]):
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate a statement."""
        if not all([
            self._check_established_trust(),
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Trust:Validate")
    def validate(self, native: Portfolio, foreign: Portfolio) -> bool:
        """Perform validation of revoked statement for portfolio."""
        self._portfolio = native
        self._owner = foreign
        self._applier()
        return True