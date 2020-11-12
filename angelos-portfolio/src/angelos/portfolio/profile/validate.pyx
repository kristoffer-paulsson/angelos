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
from angelos.document.profiles import Profile
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.policy import DocumentPolicy


class ValidateProfile(DocumentPolicy, PolicyValidator, PolicyMixin):
    """Validate updated profile."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None

    def apply(self) -> bool:
        """Perform logic to validate updated profile with current."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Profile:Validate")
    def validate(self, portfolio: Portfolio, profile: Profile) -> bool:
        """Perform validation of updated domain for portfolio."""
        self._portfolio = portfolio
        self._document = profile
        self._applier()
        return True