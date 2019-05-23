# cython: language_level=3
"""Module docstring."""
from .model import BaseDocument, TypeField
from .document import DocType, Document, OwnerMixin, IssueMixin
from .model import UuidField


class Statement(Document):
    def _validate(self):
        return True


class Verified(Statement, OwnerMixin):
    type = TypeField(value=DocType.STAT_VERIFIED)

    def _validate(self):
        self._check_type(DocType.STAT_VERIFIED)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Verified,
                    OwnerMixin]
        self._check_validate(validate)
        return True


class Trusted(Statement, OwnerMixin):
    type = TypeField(value=DocType.STAT_TRUSTED)

    def _validate(self):
        self._check_type(DocType.STAT_TRUSTED)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Trusted,
                    OwnerMixin]
        self._check_validate(validate)
        return True


class Revoked(Statement):
    type = TypeField(value=DocType.STAT_REVOKED)
    issuance = UuidField()

    def _validate(self):
        self._check_type(DocType.STAT_REVOKED)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Statement, Revoked]
        self._check_validate(validate)
        return True
