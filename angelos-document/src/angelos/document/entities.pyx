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
"""Module docstring."""
from angelos.document.document import DocType, Document, ChangeableMixin
from angelos.document.entity_mixin import PersonMixin, MinistryMixin, ChurchMixin
from angelos.document.model import TypeField, BinaryField, SignatureField


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
    type = TypeField(value=int(DocType.KEYS_PRIVATE))
    secret = BinaryField()
    seed = BinaryField()
    signature = SignatureField()

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_expiry_period()
        self._check_doc_type(DocType.KEYS_PRIVATE)
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
    type = TypeField(value=int(DocType.KEYS))
    verify = BinaryField()
    public = BinaryField()
    signature = SignatureField(multiple=True)

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_expiry_period()
        self._check_doc_type(DocType.KEYS)
        return True


class Entity(Document, ChangeableMixin):
    """Short summary."""
    def apply_rules(self):
        return True


class Person(Entity, PersonMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.ENTITY_PERSON))

    def changeables(self) -> tuple:
        """Fields that are changeable when updating."""
        return "family_name",

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_expiry_period()
        self._check_doc_type(DocType.ENTITY_PERSON)
        return True


class Ministry(Entity, MinistryMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.ENTITY_MINISTRY))

    def changeables(self) -> tuple:
        """Fields that are changeable when updating."""
        return "vision",

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_expiry_period()
        self._check_doc_type(DocType.ENTITY_MINISTRY)
        return True


class Church(Entity, ChurchMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.ENTITY_CHURCH))

    def changeables(self):
        """Fields that are changeable when updating."""
        return "region", "country"

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_expiry_period()
        self._check_doc_type(DocType.ENTITY_CHURCH)
        return True
