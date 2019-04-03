from .model import (
    BaseDocument, StringField, DateField, BinaryField, DocumentField,
    UuidField, TypeField)
from .document import Document, OwnerMixin, IssueMixin


class Attachment(BaseDocument):
    name = StringField()
    mime = StringField()
    data = BinaryField()


class Message(Document, OwnerMixin):
    expires = DateField(required=False)
    reply = UuidField(required=False)
    body = StringField(required=False)


class Note(Message):
    type = TypeField(value=Document.Type.COM_NOTE)

    def _validate(self):
        self._check_type(Document.Type.COM_NOTE)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Note]
        self._check_validate(validate)
        return True


class Instant(Message):
    type = TypeField(value=Document.Type.COM_INSTANT)
    body = BinaryField()
    mime = StringField()

    def _validate(self):
        self._check_type(Document.Type.COM_INSTANT)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Instant]
        self._check_validate(validate)
        return True


class Mail(Message):
    type = TypeField(value=Document.Type.COM_MAIL)
    subject = StringField(required=False)
    attachment = DocumentField(required=False, t=Attachment, multiple=True)

    def _validate(self):
        self._check_type(Document.Type.COM_MAIL)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Mail]
        self._check_validate(validate)
        return True


class Share(Mail):
    type = TypeField(value=Document.Type.COM_SHARE)

    def _validate(self):
        self._check_type(Document.Type.COM_SHARE)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Mail, Share]
        self._check_validate(validate)
        return True


class Report(Mail):
    type = TypeField(value=Document.Type.COM_REPORT)

    def _validate(self):
        self._check_type(Document.Type.COM_REPORT)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Mail, Share]
        self._check_validate(validate)
        return True
