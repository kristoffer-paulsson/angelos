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
from typing import Tuple

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy
from angelos.document.statements import Trusted, Verified, Revoked
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, Portfolio


class StatementCreateException(RuntimeError):
    ENTITY_NOT_IN_OWNER = ("Entity not present in owning portfolio.", 100)
    WRONG_ISSUER = ("Issuance is not issued by issuer.", 101)


class BaseCreateStatement(PolicyPerformer):
    """Initialize the statement generator"""
    def __init__(self):
        super().__init__()
        self._klass = None
        self._issuer = None
        self._owner = None
        self._statement = None

    def _clean(self):
        pass


class CreateStatementMixin(PolicyMixin):
    """Logic fo generating a Statement Portfolio."""

    def apply(self) -> bool:
        """Perform logic to create a new statement."""

        if not self._owner.entity:
            raise StatementCreateException(*StatementCreateException.ENTITY_NOT_IN_OWNER)

        self._statement = self._klass(nd={
            "issuer": self._issuer.entity.id,
            "owner": self._owner.entity.id
        })

        self._statement = Crypto.sign(self._statement, self._issuer)
        self._statement.validate()
        self._issuer.__init__(self._issuer.documents() | {self._statement})
        return True


class CreateTrustedStatement(BaseCreateStatement, CreateStatementMixin):
    """Generate new trust statement for portfolio."""

    def _setup(self):
        self._klass = Trusted

    @policy(b'I', 0, "Trusted:Create")
    def perform(self, issuer: PrivatePortfolio, owner: Portfolio) -> Trusted:
        """Perform build of trusted statement."""
        self._issuer = issuer
        self._owner = owner
        self._applier()
        return self._statement


class CreateVerifiedStatement(BaseCreateStatement, CreateStatementMixin):
    """Generate new verified statement for portfolio."""

    def _setup(self):
        self._klass = Verified

    @policy(b'I', 0, "Verified:Create")
    def perform(self, issuer: PrivatePortfolio, owner: Portfolio) -> Verified:
        """Perform build of trusted statement."""
        self._issuer = issuer
        self._owner = owner
        self._applier()
        return self._statement


class BaseCreateRevoked(PolicyPerformer):
    """Initialize the revoke generator"""
    def __init__(self):
        super().__init__()
        self._issuer = None
        self._issuance = None
        self._statement = None

    def _setup(self):
        self._statement = None

    def _clean(self):
        self._issuer = None
        self._issuance = None


class CreateRevokedMixin(PolicyMixin):
    """Logic fo generating a revoke statement by portfolio."""

    def apply(self) -> bool:
        """Perform logic to create a new revoked statement."""

        if not self._issuance.issuer == self._issuer.entity.id:
            raise StatementCreateException(*StatementCreateException.WRONG_ISSUER)

        self._statement = Revoked(nd={
            "issuer": self._issuer.entity.id,
            "issuance": self._issuance.id
        })

        self._statement = Crypto.sign(self._statement, self._issuer)
        self._statement.validate()
        self._issuer.__init__(self._issuer.documents() | {self._statement})
        return True


class CreateRevokedStatement(BaseCreateRevoked, CreateRevokedMixin):
    """Generate new revoked statement for portfolio."""

    @policy(b'I', 0, "Revoked:Create")
    def perform(self, issuer: PrivatePortfolio, issuance: Tuple[Trusted, Verified]) -> Revoked:
        """Perform build of revoked statement."""
        self._issuer = issuer
        self._issuance = issuance
        self._applier()
        return self._statement