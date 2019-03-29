from .model import (
    BaseDocument, StringField, DateField, BytesField, DocumentField, UuidField)
from .document import Document, OwnerMixin, IssueMixin


class Attachment(BaseDocument):
    name = StringField()
    mime = StringField()
    data = BytesField()


class Message(Document, OwnerMixin):
    expires = DateField(required=False)
    reply = UuidField(required=False)
    body = StringField(required=False)


class Note(Message):
    type = StringField('doc.com.note')

    def _validate(self):
        self._check_type('doc.com.note')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Note]
        self._check_validate(self, validate)
        return True


class Instant(Message):
    type = StringField('doc.com.msg')
    body = BytesField()
    mime = StringField()

    def _validate(self):
        self._check_type('dot.com.msg')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Instant]
        self._check_validate(self, validate)
        return True


class Mail(Message):
    type = StringField('doc.com.mail')
    subject = StringField(required=False)
    attachment = DocumentField(required=False, t=Attachment, multiple=True)

    def _validate(self):
        self._check_type('doc.com.mail')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Mail]
        self._check_validate(self, validate)
        return True


class Share(Mail):
    type = StringField('doc.com.share')

    def _validate(self):
        self._check_type('doc.com.share')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Mail, Share]
        self._check_validate(self, validate)
        return True


class Report(Mail):
    type = StringField('doc.com.report')

    def _validate(self):
        self._check_type('com.com.report')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Message, OwnerMixin,
                    Mail, Share]
        self._check_validate(self, validate)
        return True
