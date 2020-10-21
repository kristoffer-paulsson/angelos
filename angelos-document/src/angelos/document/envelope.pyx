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
import datetime

from angelos.common.policy import policy
from angelos.document.document import DocType, Document, OwnerMixin, DocumentError
from angelos.document.model import BaseDocument, DateField, StringField, UuidField, DocumentField, BinaryField, \
    TypeField, SignatureField, DateTimeField


ENVELOPE_EXPIRY_PERIOD = 31


class Header(BaseDocument):
    """Short summary.

    Attributes
    ----------
    op : StringField
        Description of attribute `op`.
    issuer : UuidField
        Description of attribute `issuer`.
    timestamp : DateTimeField
        Description of attribute `timestamp`.
    signature : SignatureField
        Description of attribute `signature`.
    """
    op = StringField()
    issuer = UuidField()
    timestamp = DateTimeField()
    signature = SignatureField()

    class Op:
        """Short summary."""
        SEND = "SEND"
        ROUTE = "RTE"
        RECEIVE = "RECV"


class Envelope(Document, OwnerMixin):
    """Short summary.

    Attributes
    ----------
    type : TypeField
        Description of attribute `type`.
    expires : DateField
        Description of attribute `expires`.
    message : BinaryField
        Description of attribute `message`.
    header : DocumentField
        Description of attribute `header`.
    posted : DateTimeField
        Description of attribute `posted`.
    """
    type = TypeField(value=int(DocType.COM_ENVELOPE))
    expires = DateField(
        init=lambda: (datetime.date.today() + datetime.timedelta(ENVELOPE_EXPIRY_PERIOD))
    )
    message = BinaryField(limit=131072)
    header = DocumentField(required=False, doc_class=Header, multiple=True)
    posted = DateTimeField()

    def period(self) -> float:
        """The Delta period to expiry date.

        Returns (datetime.timedelta):
            The Delta period.

        """
        return ENVELOPE_EXPIRY_PERIOD

    def apply_rules(self) -> bool:
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        return all([
            self._check_expiry_period(),
            self._check_doc_type(DocType.COM_ENVELOPE)
        ])
