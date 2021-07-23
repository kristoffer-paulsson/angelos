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
"""Updating an entity portfolio for Person, Ministry and Church documents."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.entities import Person, Ministry, Church
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.policy import UpdatablePolicy


class UpdateEntityMixin(UpdatablePolicy, PolicyMixin):
    """Logic for updating Entity in an existing PrivatePortfolio."""

    def __init__(self):
        super().__init__()
        self._data = None

    def _setup(self):
        pass

    def _clean(self):
        self._data = None

    def apply(self) -> bool:
        """Perform logic to create a new entity with its new portfolio."""
        self._former = self._portfolio.entity
        self._document = self._former

        if self._data:
            self.field_update(self._document.changeables(), dict(self._data._asdict()))
        self._document.renew()
        Crypto.sign(self._document, self._portfolio)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_fields_unchanged() if self._former else True
        ]):
            raise PolicyException()

        self._update()
        return True


class UpdatePersonEntity(UpdateEntityMixin, PolicyPerformer):
    """Update entity document of person portfolio from data."""

    @policy(b'I', 0, "Person:Update")
    def perform(self, portfolio: PrivatePortfolio, data: PersonData = None) -> Person:
        """Perform update of person portfolio."""
        self._portfolio = portfolio
        self._data = data
        self._applier()
        return self._document


class UpdateMinistryEntity(UpdateEntityMixin, PolicyPerformer):
    """Update entity document of ministry portfolio from data."""

    @policy(b'I', 0, "Ministry:Update")
    def perform(self, portfolio: PrivatePortfolio, data: MinistryData = None) -> Ministry:
        """Perform update of ministry portfolio."""
        self._portfolio = portfolio
        self._data = data
        self._applier()
        return self._document


class UpdateChurchEntity(UpdateEntityMixin, PolicyPerformer):
    """Update entity document of church portfolio from data."""

    @policy(b'I', 0, "Church:Update")
    def perform(self, portfolio: PrivatePortfolio, data: ChurchData = None) -> Church:
        """Perform update of church portfolio."""
        self._portfolio = portfolio
        self._data = data
        self._applier()
        return self._document