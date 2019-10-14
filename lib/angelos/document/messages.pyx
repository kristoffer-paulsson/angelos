# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
from .model import (
    BaseDocument,
    StringField,
    DateField,
    BinaryField,
    DocumentField,
    UuidField,
    TypeField,
    DateTimeField,
)
from .document import DocType, Document, OwnerMixin, IssueMixin


class Attachment(BaseDocument):
    name = StringField()
    mime = StringField()
    data = BinaryField()


class Message(Document, OwnerMixin):
    expires = DateField(required=False)
    reply = UuidField(required=False)
    body = StringField(required=False)
    posted = DateTimeField()


class Note(Message):
    type = TypeField(value=DocType.COM_NOTE)

    def _validate(self):
        self._check_type(DocType.COM_NOTE)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Message,
            OwnerMixin,
            Note,
        ]
        self._check_validate(validate)
        return True


class Instant(Message):
    type = TypeField(value=DocType.COM_INSTANT)
    body = BinaryField()
    mime = StringField()

    def _validate(self):
        self._check_type(DocType.COM_INSTANT)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Message,
            OwnerMixin,
            Instant,
        ]
        self._check_validate(validate)
        return True


class Mail(Message):
    type = TypeField(value=DocType.COM_MAIL)
    subject = StringField(required=False)
    attachments = DocumentField(required=False, t=Attachment, multiple=True)

    def _validate(self):
        self._check_type(DocType.COM_MAIL)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Message,
            OwnerMixin,
            Mail,
        ]
        self._check_validate(validate)
        return True


class Share(Mail):
    type = TypeField(value=DocType.COM_SHARE)

    def _validate(self):
        self._check_type(DocType.COM_SHARE)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Message,
            OwnerMixin,
            Mail,
            Share,
        ]
        self._check_validate(validate)
        return True


class Report(Mail):
    type = TypeField(value=DocType.COM_REPORT)

    def _validate(self):
        self._check_type(DocType.COM_REPORT)
        return True

    def validate(self):
        validate = [
            BaseDocument,
            Document,
            IssueMixin,
            Message,
            OwnerMixin,
            Mail,
            Share,
        ]
        self._check_validate(validate)
        return True
