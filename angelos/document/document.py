import datetime
import uuid

from ..utils import Util
from ..error import Error
from .model import (
    DocumentMeta, BaseDocument, UuidField, DateField, StringField)


class IssueMixin(metaclass=DocumentMeta):
    signature = StringField()
    issuer = UuidField()

    def _validate(self):
        return True


class OwnerMixin(metaclass=DocumentMeta):
    owner = UuidField()

    def _validate(self):
        return True


class UpdatedMixin(metaclass=DocumentMeta):
    updated = DateField(required=False)

    def _validate(self):
        # Validate that "expires" is at least 13 months in the future compared
        # to "created" if "updated" is null
        try:
            if bool(self.updated):
                if self.expires - self.updated > datetime.timedelta(13*365/12):
                    raise Util.exception(
                        Error.DOCUMENT_SHORT_EXPIREY,
                        {'expected': datetime.timedelta(13*365/12),
                         'current': self.expires - self.updated})
        except AttributeError:
            pass
        return True


class Document(IssueMixin, BaseDocument):
    id = UuidField(init=uuid.uuid4)
    created = DateField(init=datetime.date.today)
    expires = DateField(init=lambda: (
        datetime.date.today() + datetime.timedelta(13*365/12)))
    type = StringField()

    def _validate(self):
        # Validate that "expires" is at least 13 months in the future compared
        # to "created" if "updated" is null
        try:
            if not bool(self.updated):
                if self.expires - self.created > datetime.timedelta(13*365/12):
                    raise Util.exception(
                        Error.DOCUMENT_SHORT_EXPIREY,
                        {'expected': datetime.timedelta(13*365/12),
                         'current': self.expires - self.created})
        except AttributeError:
            pass
        return True

    def _check_type(self, _type):
        if not self.type == _type:
            raise Util.exception(
                Error.DOCUMENT_INVALID_TYPE,
                {'expected': _type,
                 'current': self.type})

    def _check_validate(self, _list):
        for cls in _list:
            cls._validate(self)
