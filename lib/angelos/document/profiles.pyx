# cython: language_level=3
"""Module docstring."""
from .model import (
    BaseDocument, StringField, DateField, ChoiceField, EmailField, BinaryField,
    DocumentField, TypeField)
from .document import Document, UpdatedMixin, IssueMixin
from .entity_mixin import PersonMixin, MinistryMixin, ChurchMixin


class Address(BaseDocument):
    co = StringField(required=False)
    organisation = StringField(required=False)
    department = StringField(required=False)
    apartment = StringField(required=False)
    floor = StringField(required=False)
    building = StringField(required=False)
    street = StringField(required=False)
    number = StringField(required=False)
    area = StringField(required=False)
    city = StringField(required=False)
    pobox = StringField(required=False)
    zip = StringField(required=False)
    subregion = StringField(required=False)
    region = StringField(required=False)
    country = StringField(required=False)


class Social(BaseDocument):
    token = StringField()
    service = StringField()


class Profile(Document, UpdatedMixin):
    picture = BinaryField(required=False, limit=65536)
    email = EmailField(required=False)
    mobile = StringField(required=False)
    phone = StringField(required=False)
    address = DocumentField(required=False, t=Address)
    language = StringField(required=False, multiple=True)
    social = DocumentField(required=False, t=Social, multiple=True)


class PersonProfile(Profile, PersonMixin):
    type = TypeField(value=Document.Type.PROF_PERSON)
    gender = ChoiceField(required=False, choices=['man', 'woman', 'undefined'])
    born = DateField(required=False)
    names = StringField(required=False, multiple=True)

    def _validate(self):
        self._check_type(Document.Type.PROF_PERSON)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Profile, UpdatedMixin,
                    PersonProfile, PersonMixin]
        self._check_validate(validate)
        return True


class MinistryProfile(Profile, MinistryMixin):
    type = TypeField(value=Document.Type.PROF_MINISTRY)

    def _validate(self):
        self._check_type(Document.Type.PROF_MINISTRY)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Profile, UpdatedMixin,
                    MinistryProfile, MinistryMixin]
        self._check_validate(validate)
        return True


class ChurchProfile(Profile, ChurchMixin):
    type = TypeField(value=Document.Type.PROF_CHURCH)

    def _validate(self):
        self._check_type(Document.Type.PROF_CHURCH)
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Profile, UpdatedMixin,
                    ChurchProfile, ChurchMixin]
        self._check_validate(validate)
        return True
