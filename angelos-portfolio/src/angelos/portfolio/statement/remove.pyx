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
"""Doc string"""
from typing import Union

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy
from angelos.document.statements import Revoked, Trusted, Verified
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.policy import DocumentPolicy


class StatementRemoveException(RuntimeError):
    WRONG_ISSUER = ("Revoked is not issued by issuer.", 100)
    WRONG_TYPE = ("Revoked is not trusted or verified document type.", 101)


class RemoveRevokedStatement(DocumentPolicy, PolicyMixin, PolicyPerformer):
    """Remove revoked statement for portfolio."""

    def __init__(self):
        super().__init__()
        self._revoked = None

    def _setup(self):
        self._document = None

    def _clean(self):
        self._portfolio = None
        self._revoked = None

    def apply(self) -> bool:
        """Perform logic to remove a revoked statement."""

        if not self._revoked.issuer == self._portfolio.entity.id:
            raise StatementRemoveException(*StatementRemoveException.WRONG_ISSUER)

        self._document = self._portfolio.get_id(self._revoked.issuance)

        if not isinstance(self._document, (Trusted, Verified, type(None))):
            raise StatementRemoveException(*StatementRemoveException.WRONG_TYPE)

        self._portfolio.__init__(self._portfolio.filter({self._document, self._revoked}) | {self._revoked})
        return True

    @policy(b'I', 0, "Revoked:Remove")
    def perform(self, issuer: Portfolio, revoked: Revoked) -> Union[Trusted, Verified]:
        """Perform removal of revoked statement."""
        self._portfolio = issuer
        self._revoked = revoked
        self._applier()
        return self._document