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
"""Policy performers and validators for entity documents."""
from angelos.bin.nacl import DualSecret
from angelos.common.policy import PolicyValidator, PolicyMixin, policy, evaluate, PolicyException, PolicyPerformer
from angelos.document.document import DocumentError
from angelos.document.entities import Person, Ministry, Church, PrivateKeys, Keys
from angelos.document.model import FieldError
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

    @policy(section=b'I', sn=0)
    def apply(self) -> bool:
        """Perform logic to create a new entity with its new portfolio."""
        box = DualSecret()

        entity = self._klass(nd=dict(self._data._asdict()))
        entity.issuer = entity.id
        entity.signature = box.signature(entity.issuer.bytes + Crypto.document_data(entity))

        privkeys = PrivateKeys(nd={"issuer": entity.id, "secret": box.sk, "seed": box.seed})
        privkeys.signature = box.signature(privkeys.issuer.bytes + Crypto.document_data(privkeys))

        keys = Keys(nd={"issuer": entity.id, "public": box.pk, "verify": box.vk})
        keys.signature = [box.signature(keys.issuer.bytes + Crypto.document_data(keys))]

        entity.validate()
        privkeys.validate()
        keys.validate()

        self._portfolio = PrivatePortfolio({entity, privkeys, keys}, False)


class CreatePersonEntity(BaseCreateEntity, CreateEntityMixin):
    """Generate new person portfolio from data."""
    def _setup(self):
        self._klass = Person

    @evaluate("Generate:Person")
    def perform(self, data: PersonData) -> PrivatePortfolio:
        """Perform building of person portfolio."""
        self._data = data
        self._applier()
        return self._portfolio


class CreateMinistryEntity(BaseCreateEntity, CreateEntityMixin):
    """Generate new ministry portfolio from data."""
    def _setup(self):
        self._klass = Ministry

    @evaluate("Generate:Ministry")
    def perform(self, data: MinistryData) -> PrivatePortfolio:
        """Perform building of ministry portfolio."""
        self._data = data
        self._applier()
        return self._portfolio


class CreateChurchEntity(BaseCreateEntity, CreateEntityMixin):
    """Generate new church portfolio from data."""
    def _setup(self):
        self._klass = Church

    @evaluate("Generate:Church")
    def perform(self, data: ChurchData) -> PrivatePortfolio:
        """Perform building of church portfolio."""
        self._data = data
        self._applier()
        return self._portfolio


class ValidateEntityDocument(PolicyMixin):
    """Run validation on an entity document."""

    @policy(b"I", 0, "Document")
    def apply(self) -> bool:
        """Run document validation"""
        try:
            self._entity.validate()
        except (FieldError, DocumentError) as e:
            raise PolicyException(e)
        return True


class BaseEntityValidator(PolicyValidator, ValidateEntityDocument):
    def __init__(self):
        super().__init__()
        self._entity = None

    def _setup(self):
        pass

    def _clean(self):
        pass


class PersonEntityValidator(BaseEntityValidator):
    """Validator of person entity documents, policy ring 2."""

    def validate(self, person: Person):
        """Validate person entity document."""
        self._entity = person
        with evaluate("Person {}".format(person.id)) as r:
            self._applier()
            print(r.format())


class MinistryEntityValidator(BaseEntityValidator):
    """Validator of ministry entity documents, policy ring 2."""

    def validate(self, ministry: Ministry):
        """Validate ministry entity document."""
        self._entity = ministry
        with evaluate("Ministry {}".format(ministry.id)) as r:
            self._applier()
            print(r.format())


class ChurchEntityValidator(BaseEntityValidator):
    """Validator of church entity documents, policy ring 2."""

    def validate(self, church: Church):
        """Validate church entity document."""
        self._entity = church
        with evaluate("Church {}".format(church.id)) as r:
            self._applier()
            print(r.format())
