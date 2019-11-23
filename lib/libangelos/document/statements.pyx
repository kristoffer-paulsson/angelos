# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
from .model import BaseDocument, TypeField
from .document import DocType, Document, OwnerMixin, IssueMixin
from .model import UuidField


class Statement(Document):
    """Short summary."""
    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return True


class Verified(Statement, OwnerMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=DocType.STAT_VERIFIED)

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.STAT_VERIFIED)
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
            Statement,
            Verified,
            OwnerMixin,
        ]
        self._check_validate(validate)
        return True


class Trusted(Statement, OwnerMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=DocType.STAT_TRUSTED)

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.STAT_TRUSTED)
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
            Statement,
            Trusted,
            OwnerMixin,
        ]
        self._check_validate(validate)
        return True


class Revoked(Statement):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    issuance : UuidField
        Description of attribute `issuance`.
    """
    type = TypeField(value=DocType.STAT_REVOKED)
    issuance = UuidField()

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.STAT_REVOKED)
        return True

    def validate(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        validate = [BaseDocument, Document, IssueMixin, Statement, Revoked]
        self._check_validate(validate)
        return True
