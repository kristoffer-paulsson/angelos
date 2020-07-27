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
"""Miscellaneous documents."""
import datetime

from angelos.document.document import Document, DocType, DocumentError
from angelos.document.envelope import Envelope
from angelos.document.messages import Message
from angelos.document.model import TypeField, DateField, DocumentField, UuidField


class StoredLetter(Document):
    """Short summary.

    Attributes
    ----------
    id : UuidField
        Description of attribute `id`.
    type : TypeField
        Description of attribute `type`.
    expires : DateField
        Description of attribute `expires`.
    envelope : DocumentField
        Description of attribute `envelope`.
    message : DocumentField
        Description of attribute `message`.
    """
    id = UuidField()
    type = TypeField(value=int(DocType.CACHED_MSG))
    expires = DateField(
        init=lambda: (datetime.date.today() + datetime.timedelta(3 * 365 / 12))
    )
    envelope = DocumentField(doc_class=Envelope)
    message = DocumentField(doc_class=Message)

    def _check_expiry_period(self):
        """Checks the expiry time period.

        The time period between update date and
        expiry date should not be less than 90 days.
        """
        if self.expires:
            if (self.expires - self.created) < datetime.timedelta(3 * 365 / 12 - 1):
                raise DocumentError(
                    *DocumentError.DOCUMENT_SHORT_EXPIRY,
                    {"expected": datetime.timedelta(91), "current": self.expires - self.created})

    def _check_document_id(self):
        # if not self.message and self.id:
        #    return
        slid = getattr(self, "id", None)
        message = getattr(self, "message", None)
        mid = getattr(message, "id", None) if message else message

        if slid != mid:
            raise DocumentError(*DocumentError.DOCUMENT_WRONG_ID, {"expected": self.message.id, "current": self.id})

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_expiry_period()
        self._check_doc_type(DocType.CACHED_MSG)
        self._check_document_id()
        return True
