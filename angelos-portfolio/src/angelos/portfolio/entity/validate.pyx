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
"""Creating new entity portfolio for Person, Ministry and Church including Keys and PrivateKeys documents."""
from angelos.common.policy import PolicyMixin, policy, PolicyException, PolicyValidator
from angelos.document.entities import PrivateKeys
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.policy import DocumentPolicy


class ValidatePrivateKeys(DocumentPolicy, PolicyValidator, PolicyMixin):
    """Validate private keys."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None

    def apply(self) -> bool:
        """Perform logic to validate private keys."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "PrivateKeys:ValidatePrivate")
    def validate(self, portfolio: PrivatePortfolio, privkeys: PrivateKeys) -> bool:
        """Perform validation of updated domain for portfolio."""
        self._portfolio = portfolio
        self._document = privkeys
        self._applier()
        return True