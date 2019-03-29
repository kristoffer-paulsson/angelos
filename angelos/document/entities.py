from .model import BaseDocument, StringField
from .document import Document, UpdatedMixin, IssueMixin
from .entity_mixin import PersonMixin, MinistryMixin, ChurchMixin


class Keys(Document):
    type = StringField(value='cert.keys')
    verify = StringField()
    public = StringField()

    def _validate(self):
        self._check_type('cert.keys')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Keys]
        self._check_validate(self, validate)
        return True


class Entity(Document, UpdatedMixin):
    def _validate(self):
        return True


class Person(Entity, PersonMixin):
    type = StringField(value='entity.person')

    def _validate(self):
        self._check_type('entity.person')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Entity, UpdatedMixin,
                    Person, PersonMixin]
        self._check_validate(self, validate)
        return True


class Ministry(Entity, MinistryMixin):
    type = StringField(value='entity.ministry')

    def _validate(self):
        self._check_type('entity.ministry')
        return True

    def validate(self):
        validate = [BaseDocument,  Document, IssueMixin, Entity, UpdatedMixin,
                    Ministry, MinistryMixin]
        self._check_validate(self, validate)
        return True


class Church(Entity, ChurchMixin):
    type = StringField(value='entity.church')

    def _validate(self):
        self._check_type('entity.church')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Entity, UpdatedMixin,
                    Church, ChurchMixin]
        self._check_validate(self, validate)
        return True
