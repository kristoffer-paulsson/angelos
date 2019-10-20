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
    """Short summary."""
    type = TypeField(value=DocType.KEYS_PRIVATE)
    secret = BinaryField()
    seed = BinaryField()
    signature = SignatureField()

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.KEYS_PRIVATE)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [BaseDocument, Document, IssueMixin, PrivateKeys]
        self._check_validate(validate)
        return True


class Keys(Document):
    """Short summary."""
    type = TypeField(value=DocType.KEYS)
    verify = BinaryField()
    public = BinaryField()
    signature = SignatureField(multiple=True)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.KEYS)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [BaseDocument, Document, IssueMixin, Keys]
        self._check_validate(validate)
        return True


class Entity(Document, UpdatedMixin):
    """Short summary."""
    def _validate(self):
        return True


class Person(Entity, PersonMixin):
    """Short summary."""
    type = TypeField(value=DocType.ENTITY_PERSON)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.ENTITY_PERSON)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
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
    """Short summary."""
    type = TypeField(value=DocType.ENTITY_MINISTRY)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.ENTITY_MINISTRY)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
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
    """Short summary."""
    type = TypeField(value=DocType.ENTITY_CHURCH)

    def _validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.ENTITY_CHURCH)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
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
