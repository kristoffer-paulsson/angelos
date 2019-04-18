"""Module docstring."""
import datetime

from ..utils import Util
from ..error import Error

from .model import (
    BaseDocument, DateField, StringField, UuidField, DocumentField,
    BinaryField, TypeField)
from .document import Document, OwnerMixin, IssueMixin


class Header(BaseDocument):
    op = StringField()
    domain = UuidField()
    node = UuidField()
    signature = StringField()


class Envelope(Document, OwnerMixin):
    type = TypeField(value=Document.Type.COM_ENVELOPE)
    expires = DateField(required=True, init=lambda: (
        datetime.date.today() + datetime.timedelta(31)))
    message = BinaryField(limit=131072)
    header = DocumentField(t=Header, multiple=True)

    def _validate(self):
        self._check_type(Document.Type.COM_ENVELOPE)

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
