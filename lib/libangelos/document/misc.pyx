# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Miscellaneous documents."""
import datetime

from ..error import Error
from ..utils import Util

from .model import TypeField, DateField, DocumentField, UuidField, BaseDocument
from .document import Document, DocType, IssueMixin
from .messages import Message
from .envelope import Envelope


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
    type = TypeField(value=DocType.CACHED_MSG)
    expires = DateField(
        init=lambda: (datetime.date.today() + datetime.timedelta(365 / 12 * 3))
    )
    envelope = DocumentField(doc_class=Envelope)
    message = DocumentField(doc_class=Message)

    def _check_document_id(self):
        # if not self.message and self.id:
        #    return
        slid = getattr(self, "id", None)
        message = getattr(self, "message", None)
        mid = getattr(message, "id", None) if message else message

        if slid != mid:
            raise Util.exception(
                Error.DOCUMENT_WRONG_ID,
                {
                    "expected": self.message.id,
                    "current": self.id,
                },
            )
            raise ValueError("StoredLetter ID is not the same as Message ID.")

    def apply_rules(self):
        """Short summary.

        Returns
        -------
        type
            Description of returned object.

        """
        self._check_type(DocType.CACHED_MSG)
        self._check_document_id()
        return True
