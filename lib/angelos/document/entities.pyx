# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
from .model import BaseDocument, TypeField, BinaryField, SignatureField
from .document import DocType, Document, UpdatedMixin, IssueMixin
from .entity_mixin import PersonMixin, MinistryMixin, ChurchMixin


class PrivateKeys(Document):
    type = TypeField(value=DocType.KEYS_PRIVATE)
    secret = BinaryField()
    seed = BinaryField()
    signature = SignatureField()

    def _validate(self):
        self._check_type(DocType.KEYS_PRIVATE)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, PrivateKeys]
        self._check_validate(validate)
        return True


class Keys(Document):
    type = TypeField(value=DocType.KEYS)
    verify = BinaryField()
    public = BinaryField()
    signature = SignatureField(multiple=True)

    def _validate(self):
        self._check_type(DocType.KEYS)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Keys]
        self._check_validate(validate)
        return True


class Entity(Document, UpdatedMixin):
    def _validate(self):
        return True


class Person(Entity, PersonMixin):
    type = TypeField(value=DocType.ENTITY_PERSON)

    def _validate(self):
        self._check_type(DocType.ENTITY_PERSON)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Entity,
            UpdatedMixin,
            Person,
            PersonMixin,
        ]
        self._check_validate(validate)
        return True


class Ministry(Entity, MinistryMixin):
    type = TypeField(value=DocType.ENTITY_MINISTRY)

    def _validate(self):
        self._check_type(DocType.ENTITY_MINISTRY)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Entity,
            UpdatedMixin,
            Ministry,
            MinistryMixin,
        ]
        self._check_validate(validate)
        return True


class Church(Entity, ChurchMixin):
    type = TypeField(value=DocType.ENTITY_CHURCH)

    def _validate(self):
        self._check_type(DocType.ENTITY_CHURCH)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Entity,
            UpdatedMixin,
            Church,
            ChurchMixin,
        ]
        self._check_validate(validate)
        return True
