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

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.statements import Trusted, Verified, Revoked
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, Portfolio
from angelos.portfolio.policy import IssuePolicy, DocumentPolicy


class StatementCreateException(RuntimeError):
    ENTITY_NOT_IN_OWNER = ("Entity not present in owning portfolio.", 100)
    WRONG_ISSUER = ("Issuance is not issued by issuer.", 101)


class CreateStatementMixin(IssuePolicy, PolicyMixin):
    """Logic fo generating a Statement Portfolio."""

    def __init__(self):
        super().__init__()
        self._klass = None

    def _clean(self):
        pass

    def apply(self) -> bool:
        """Perform logic to create a new statement."""

        if not self._owner.entity:
            raise StatementCreateException(*StatementCreateException.ENTITY_NOT_IN_OWNER)

        self._document = self._klass(nd={
            "issuer": self._portfolio.entity.id,
            "owner": self._owner.entity.id
        })
        self._document = Crypto.sign(self._document, self._portfolio)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify()
        ]):
            raise PolicyException()

        self._add()
        return True


class CreateTrustedStatement(CreateStatementMixin, PolicyPerformer):
    """Generate new trust statement for portfolio."""

    def _setup(self):
        self._klass = Trusted

    @policy(b'I', 0, "Trusted:Create")
    def perform(self, issuer: PrivatePortfolio, owner: Portfolio) -> Trusted:
        """Perform build of trusted statement."""
        self._portfolio = issuer
        self._owner = owner
        self._applier()
        return self._document


class CreateVerifiedStatement(CreateStatementMixin, PolicyPerformer):
    """Generate new verified statement for portfolio."""

    def _setup(self):
        self._klass = Verified

    @policy(b'I', 0, "Verified:Create")
    def perform(self, issuer: PrivatePortfolio, owner: Portfolio) -> Verified:
        """Perform build of trusted statement."""
        self._portfolio = issuer
        self._owner = owner
        self._applier()
        return self._document


class CreateRevokedStatement(DocumentPolicy, PolicyMixin, PolicyPerformer):
    """Generate new revoked statement for portfolio."""

    def __init__(self):
        super().__init__()
        self._issuance = None

    def _setup(self):
        self._document = None

    def _clean(self):
        self._portfolio = None
        self._issuance = None

    def apply(self) -> bool:
        """Perform logic to create a new revoked statement."""

        if not self._issuance.issuer == self._portfolio.entity.id:
            raise StatementCreateException(*StatementCreateException.WRONG_ISSUER)

        self._document = Revoked(nd={
            "issuer": self._portfolio.entity.id,
            "issuance": self._issuance.id
        })
        self._document = Crypto.sign(self._document, self._portfolio)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify()
        ]):
            raise PolicyException()

        self._add()
        return True

    @policy(b'I', 0, "Revoked:Create")
    def perform(self, issuer: PrivatePortfolio, issuance: Tuple[Trusted, Verified]) -> Revoked:
        """Perform build of revoked statement."""
        self._portfolio = issuer
        self._issuance = issuance
        self._applier()
        return self._document