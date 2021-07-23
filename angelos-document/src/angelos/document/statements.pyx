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
"""Module docstring."""
from angelos.document.document import DocType, Document, OwnerMixin
from angelos.document.model import TypeField, UuidField


class Statement(Document):
    """Short summary."""
    def apply_rules(self) -> bool:
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
    type = TypeField(value=int(DocType.STAT_VERIFIED))

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.STAT_VERIFIED)
        ])


class Trusted(Statement, OwnerMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    """
    type = TypeField(value=int(DocType.STAT_TRUSTED))

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.STAT_TRUSTED)
        ])


class Revoked(Statement):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    issuance : UuidField
        Description of attribute `issuance`.
    """
    type = TypeField(value=int(DocType.STAT_REVOKED))
    issuance = UuidField()

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.STAT_REVOKED)
        ])
