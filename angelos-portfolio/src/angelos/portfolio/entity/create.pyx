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
from angelos.bin.nacl import DualSecret
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.entities import PrivateKeys, Keys, Person, Ministry, Church
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.portfolio.collection import PrivatePortfolio


class BaseCreateEntity(PolicyPerformer):
    """Initialize the entity generator"""
    def __init__(self):
        super().__init__()
        self._data = None
        self._klass = None
        self._portfolio = None

    def _clean(self):
        self._data = None


class CreateEntityMixin(PolicyMixin):
    """Logic fo generating Entity, Keys and PrivateKeys for a new PrivatePortfolio."""

    # TODO: Add cryptographical verification at the end.

    def apply(self) -> bool:
        """Perform logic to create a new entity with its new portfolio."""
        box = DualSecret()

        entity = self._klass(nd=dict(self._data._asdict()))
        entity.issuer = entity.id
        privkeys = PrivateKeys(nd={"issuer": entity.id, "secret": box.sk, "seed": box.seed})
        keys = Keys(nd={"issuer": entity.id, "public": box.pk, "verify": box.vk})

        self._portfolio = PrivatePortfolio({entity, privkeys, keys}, False)

        entity = Crypto.sign(entity, self._portfolio)
        privkeys = Crypto.sign(privkeys, self._portfolio, multiple=True)
        keys = Crypto.sign(keys, self._portfolio, multiple=True)

        if not all([
            entity.validate(),
            privkeys.validate(),
            keys.validate(),
            Crypto.verify(entity, self._portfolio),
            Crypto.verify(keys, self._portfolio),
            Crypto.verify(privkeys, self._portfolio)
        ]):
            raise PolicyException()
        return True


class CreatePersonEntity(BaseCreateEntity, CreateEntityMixin):
    """Generate new person portfolio from data."""
    def _setup(self):
        self._klass = Person

    @policy(b'I', 0, "Person:Create")
    def perform(self, data: PersonData) -> PrivatePortfolio:
        """Perform building of person portfolio."""
        self._data = data
        self._applier()
        return self._portfolio


class CreateMinistryEntity(BaseCreateEntity, CreateEntityMixin):
    """Generate new ministry portfolio from data."""
    def _setup(self):
        self._klass = Ministry

    @policy(b'I', 0, "Ministry:Create")
    def perform(self, data: MinistryData) -> PrivatePortfolio:
        """Perform building of ministry portfolio."""
        self._data = data
        self._applier()
        return self._portfolio


class CreateChurchEntity(BaseCreateEntity, CreateEntityMixin):
    """Generate new church portfolio from data."""
    def _setup(self):
        self._klass = Church

    @policy(b'I', 0, "Church:Create")
    def perform(self, data: ChurchData) -> PrivatePortfolio:
        """Perform building of church portfolio."""
        self._data = data
        self._applier()
        return self._portfolio