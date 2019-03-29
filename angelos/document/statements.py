from .model import BaseDocument, StringField
from .document import Document, OwnerMixin, IssueMixin


class Statement(Document):
    def _validate(self):
        return True


class Verified(Statement, OwnerMixin):
    type = StringField(value='stat.verified')

    def _validate(self):
        self._check_type('stat.verified')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Verified,
                    OwnerMixin]
        self._check_validate(self, validate)
        return True


class Trusted(Statement, OwnerMixin):
    type = StringField(value='stat.trusted')

    def _validate(self):
        self._check_type('stat.trusted')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Trusted,
                    OwnerMixin]
        self._check_validate(self, validate)
        return True


class Revoked(Statement):
    type = StringField(value='stat.revoked')

    def _validate(self):
        self._check_type('stat.revoked')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Revoked]
        self._check_validate(self, validate)
        return True
