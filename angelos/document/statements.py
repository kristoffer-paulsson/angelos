from .model import BaseDocument, TypeField
from .document import Document, OwnerMixin, IssueMixin


class Statement(Document):
    def _validate(self):
        return True


class Verified(Statement, OwnerMixin):
    type = TypeField(value=Document.Type.STAT_VERIFIED)

    def _validate(self):
        self._check_type(Document.Type.STAT_VERIFIED)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Verified,
                    OwnerMixin]
        self._check_validate(validate)
        return True


class Trusted(Statement, OwnerMixin):
    type = TypeField(value=Document.Type.STAT_TRUSTED)

    def _validate(self):
        self._check_type(Document.Type.STAT_TRUSTED)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Trusted,
                    OwnerMixin]
        self._check_validate(validate)
        return True


class Revoked(Statement):
    type = TypeField(value=Document.Type.STAT_REVOKED)

    def _validate(self):
        self._check_type(Document.Type.STAT_REVOKED)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Revoked]
        self._check_validate(validate)
        return True
