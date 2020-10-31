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
"""Updating an entity portfolio for Person, Ministry and Church documents."""
from typing import Any

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.entities import Person, Ministry, Church
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.portfolio.collection import PrivatePortfolio


class BaseUpdateEntity(PolicyPerformer):
    """Initialize the entity updater."""
    def __init__(self):
        super().__init__()
        self._data = None
        self._portfolio = None
        self._entity = None
        self._changeables = None

    def _setup(self):
        pass

    def _clean(self):
        self._data = None


class UpdateEntityMixin(PolicyMixin):
    """Logic for updating Entity in an existing PrivatePortfolio."""

    @policy(b'I', 0)
    def _check_field_update(self, name: str, field: Any) -> bool:
        if name in self._changeables:
            setattr(self._entity, name, field)
        elif getattr(self._entity, name, None) != field:
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to create a new entity with its new portfolio."""
        self._entity = self._portfolio.entity

        if self._data:
            valid = list()
            self._changeables = self._entity.changeables()
            for name, field in self._data._asdict().items():
                valid.append(self._check_field_update(name, field))

            if not all(valid):
                raise PolicyException()

        self._entity.renew()
        Crypto.sign(self._entity, self._portfolio)
        return self._entity.validate()


class UpdatePersonEntity(BaseUpdateEntity, UpdateEntityMixin):
    """Update entity document of person portfolio from data."""

    @policy(b'I', 0, "Person:Update")
    def perform(self, portfolio: PrivatePortfolio, data: PersonData = None) -> Person:
        """Perform update of person portfolio."""
        self._portfolio = portfolio
        self._data = data
        self._applier()
        return self._entity


class UpdateMinistryEntity(BaseUpdateEntity, UpdateEntityMixin):
    """Update entity document of ministry portfolio from data."""

    @policy(b'I', 0, "Ministry:Update")
    def perform(self, portfolio: PrivatePortfolio, data: MinistryData = None) -> Ministry:
        """Perform update of ministry portfolio."""
        self._portfolio = portfolio
        self._data = data
        self._applier()
        return self._entity


class UpdateChurchEntity(BaseUpdateEntity, UpdateEntityMixin):
    """Update entity document of church portfolio from data."""

    @policy(b'I', 0, "Church:Update")
    def perform(self, portfolio: PrivatePortfolio, data: ChurchData = None) -> Church:
        """Perform update of church portfolio."""
        self._portfolio = portfolio
        self._data = data
        self._applier()
        return self._entity