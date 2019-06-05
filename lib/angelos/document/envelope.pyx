# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring.
"""
import datetime

from ..utils import Util
from ..error import Error

from .model import (
    BaseDocument, DateField, StringField, UuidField, DocumentField,
    BinaryField, TypeField, SignatureField, DateTimeField)
from .document import DocType, Document, OwnerMixin, IssueMixin


class Header(BaseDocument):
    op = StringField()
    issuer = UuidField()
    timestamp = DateTimeField()
    signature = SignatureField()

    class Op:
        SEND = 'SEND'
        ROUTE = 'RTE'
        RECEIVE = 'RECV'


class Envelope(Document, OwnerMixin):
    type = TypeField(value=DocType.COM_ENVELOPE)
    expires = DateField(init=lambda: (
        datetime.date.today() + datetime.timedelta(31)))
    message = BinaryField(limit=131072)
    header = DocumentField(required=False, t=Header, multiple=True)
    posted = DateTimeField()

    def _validate(self):
        self._check_type(DocType.COM_ENVELOPE)

        if self.expires - self.created > datetime.timedelta(31):
            raise Util.exception(
                Error.DOCUMENT_SHORT_EXPIREY,
                {'expected': datetime.timedelta(31),
                 'current': self.expires - self.created})

        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Envelope, OwnerMixin]
        self._check_validate(validate)
        return True
