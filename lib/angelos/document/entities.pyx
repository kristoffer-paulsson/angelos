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
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    secret : BinaryField
        Description of attribute `secret`.
    seed : BinaryField
        Description of attribute `seed`.
    signature : SignatureField
        Description of attribute `signature`.
    """
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
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    verify : BinaryField
        Description of attribute `verify`.
    public : BinaryField
        Description of attribute `public`.
    signature : SignatureField
        Description of attribute `signature`.
    """
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
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
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
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
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
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
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
