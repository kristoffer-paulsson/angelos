from .model import (
    BaseDocument, StringField, DateField, ChoiceField, EmailField, BytesField,
    DocumentField)
from .document import Document, UpdatedMixin, IssueMixin
from .entity_mixin import PersonMixin, MinistryMixin, ChurchMixin


class Address(BaseDocument):
    co = StringField(required=False)
    street = StringField(required=False)
    number = StringField(required=False)
    address2 = StringField(required=False)
    zip = StringField(required=False)
    city = StringField(required=False)
    state = StringField(required=False)
    country = StringField(required=False)


class Social(BaseDocument):
    token = StringField()
    service = StringField()


class Profile(Document, UpdatedMixin):
    picture = BytesField(required=False, limit=65536)
    email = EmailField(required=False)
    mobile = StringField(required=False)
    phone = StringField(required=False)
    address = DocumentField(required=False, t=Address)
    language = StringField(required=False, multiple=True)
    social = DocumentField(required=False, t=Social, multiple=True)


class PersonProfile(Profile, PersonMixin):
    type = StringField(value='prof.person')
    gender = ChoiceField(required=False, choices=['man', 'woman', 'undefined'])
    born = DateField(required=False)
    names = StringField(required=False, multiple=True)

    def _validate(self):
        self._check_type('prof.person')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Profile, UpdatedMixin,
                    PersonProfile, PersonMixin]
        self._check_validate(self, validate)
        return True


class MinistryProfile(Profile, MinistryMixin):
    type = StringField(value='prof.ministry')

    def _validate(self):
        self._check_type('prof.ministry')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Profile, UpdatedMixin,
                    MinistryProfile, MinistryMixin]
        self._check_validate(self, validate)
        return True


class ChurchProfile(Profile, ChurchMixin):
    type = StringField(value='prof.church')

    def _validate(self):
        self._check_type('prof.church')
        return True

    def validate(self):
        validate = [BaseDocument, Document, IssueMixin, Profile, UpdatedMixin,
                    ChurchProfile, ChurchMixin]
        self._check_validate(self, validate)
        return True
