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
"""Doc string"""
from typing import Union

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy
from angelos.document.statements import Revoked, Trusted, Verified
from angelos.portfolio.collection import Portfolio


class StatementRemoveException(RuntimeError):
    WRONG_ISSUER = ("Revoked is not issued by issuer.", 100)
    WRONG_TYPE = ("Revoked is not trusted or verified document type.", 101)


class BaseRemoveRevoked(PolicyPerformer):
    """Initialize the revoke analyzer"""
    def __init__(self):
        super().__init__()
        self._issuer = None
        self._revoked = None
        self._statement = None

    def _setup(self):
        self._statement = None

    def _clean(self):
        self._issuer = None
        self._revoked = None


class RemoveRevokedMixin(PolicyMixin):
    """Logic for removed revoked statement from portfolio."""

    def apply(self) -> bool:
        """Perform logic to remove a revoked statement."""

        if not self._revoked.issuer == self._issuer.entity.id:
            raise StatementRemoveException(*StatementRemoveException.WRONG_ISSUER)

        self._statement = self._issuer.get_id(self._revoked.issuance)

        if not isinstance(self._statement, (Trusted, Verified, type(None))):
            raise StatementRemoveException(*StatementRemoveException.WRONG_TYPE)

        self._issuer.__init__(self._issuer.filter({self._statement, self._revoked}) | {self._revoked})
        return True


class RemoveRevokedStatement(BaseRemoveRevoked, RemoveRevokedMixin):
    """Remove revoked statement for portfolio."""

    @policy(b'I', 0, "Revoked:Remove")
    def perform(self, issuer: Portfolio, revoked: Revoked) -> Union[Trusted, Verified]:
        """Perform removal of revoked statement."""
        self._issuer = issuer
        self._revoked = revoked
        self._applier()
        return self._statement