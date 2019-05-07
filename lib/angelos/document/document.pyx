# cython: language_level=3
"""Module docstring."""
import datetime
import uuid
import enum

from ..utils import Util
from ..error import Error
from .model import (
    DocumentMeta, BaseDocument, UuidField, DateField, TypeField,
    SignatureField, conv_str, conv_bytes)


class IssueMixin(metaclass=DocumentMeta):
    signature = SignatureField()
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
    type = TypeField(value=0)

    def _validate(self):
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

    def export_str(self):
        return self.export(conv_str)

    def export_bytes(self):
        return self.export(conv_bytes)

    def _check_type(self, _type):
        if not self.type == _type:
            raise Util.exception(
                Error.DOCUMENT_INVALID_TYPE,
                {'expected': _type,
                 'current': self.type})

    def _check_validate(self, _list):
        for cls in _list:
            cls._validate(self)

    class Type(enum.IntEnum):
        NONE = 0

        KEYS_PRIVATE = 1

        KEYS = 10

        ENTITY_PERSON = 20
        ENTITY_MINISTRY = 21
        ENTITY_CHURCH = 22
        PROF_PERSON = 30
        PROF_MINISTRY = 31
        PROF_CHURCH = 32

        NET_DOMAIN = 40
        NET_NODE = 41
        NET_NETWORK = 42

        STAT_VERIFIED = 50
        STAT_TRUSTED = 51
        STAT_REVOKED = 52

        COM_ENVELOPE = 60

        COM_NOTE = 70
        COM_INSTANT = 71
        COM_MAIL = 72
        COM_SHARE = 73
        COM_REPORT = 74