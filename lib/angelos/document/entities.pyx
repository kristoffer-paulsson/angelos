# cython: language_level=3
"""Module docstring."""
from .model import BaseDocument, TypeField, BinaryField, SignatureField
from .document import Document, UpdatedMixin, IssueMixin
from .entity_mixin import PersonMixin, MinistryMixin, ChurchMixin


class PrivateKeys(Document):
    type = TypeField(value=Document.Type.KEYS_PRIVATE)
    secret = BinaryField()
    seed = BinaryField()
    signature = SignatureField()

    def _validate(self):
        self._check_type(Document.Type.KEYS_PRIVATE)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, PrivateKeys]
        self._check_validate(validate)
        return True


class Keys(Document):
    type = TypeField(value=Document.Type.KEYS)
    verify = BinaryField()
    public = BinaryField()
    signature = SignatureField(multiple=True)

    def _validate(self):
        self._check_type(Document.Type.KEYS)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Keys]
        self._check_validate(validate)
        return True


class Entity(Document, UpdatedMixin):
    def _validate(self):
        return True


class Person(Entity, PersonMixin):
    type = TypeField(value=Document.Type.ENTITY_PERSON)

    def _validate(self):
        self._check_type(Document.Type.ENTITY_PERSON)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Entity, UpdatedMixin,
                    Person, PersonMixin]
        self._check_validate(validate)
        return True


class Ministry(Entity, MinistryMixin):
    type = TypeField(value=Document.Type.ENTITY_MINISTRY)

    def _validate(self):
        self._check_type(Document.Type.ENTITY_MINISTRY)
        return True

    def validate(self):
        validate = [BaseDocument,  Document, IssueMixin, Entity, UpdatedMixin,
                    Ministry, MinistryMixin]
        self._check_validate(validate)
        return True


class Church(Entity, ChurchMixin):
    type = TypeField(value=Document.Type.ENTITY_CHURCH)

    def _validate(self):
        self._check_type(Document.Type.ENTITY_CHURCH)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Entity, UpdatedMixin,
                    Church, ChurchMixin]
        self._check_validate(validate)
        return True
