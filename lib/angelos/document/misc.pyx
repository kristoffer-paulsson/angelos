# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Miscellaneous documents.
"""
import datetime

from .model import TypeField, DateField, DocumentField, UuidField, BaseDocument
from .document import Document, DocType, IssueMixin
from .messages import Message
from .envelope import Envelope


class StoredLetter(Document):
    id = UuidField()
    type = TypeField(value=DocType.CACHED_MSG)
    expires = DateField(init=lambda: (
        datetime.date.today() + datetime.timedelta(3*365/12)))
    envelope = DocumentField(t=Envelope)
    message = DocumentField(t=Message)

    def _validate(self):
        self._check_type(DocType.CACHED_MSG)

        if self.id.int != self.message.id.int:
            raise ValueError('StoredLetter ID is not the same as Message ID.')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, StoredLetter]
        self._check_validate(validate)
        return True
