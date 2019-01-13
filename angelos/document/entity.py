import datetime

from ..utils import Util
from ..error import Error
from .model import BaseDocument
from .document import Document
from .model import DateField, StringField, ChoiceField


class Entity(Document):
    updated = DateField(required=False)

    def _validate(self):
        # Validate that "expires" is at least 13 months in the future compared
        # to "updated"
        if bool(self.updated):
            if self.expires - self.updated > datetime.timedelta(13*365/12):
                raise Util.exception(
                    Error.DOCUMENT_SHORT_EXPIREY,
                    {'expected': datetime.timedelta(13*365/12),
                     'current': self.expires - self.created})
        return True


class VirtualPerson(Entity):
    founded = DateField()


class Church(VirtualPerson):
    type = StringField(value='entity.church')
    nation = StringField(required=False)
    state = StringField(required=False)
    city = StringField()


class Ministry(VirtualPerson):
    type = StringField(value='entity.ministry')
    ministry = StringField()
    vision = StringField(required=False)


class Person(Entity):
    type = StringField(value='entity.person')
    given_name = StringField()
    family_name = StringField()
    names = StringField(multiple=True)
    born = DateField()
    gender = ChoiceField(choices=['man', 'woman', 'undefined'])

    def _validate(self):
        # Validate that "type" is of correct type
        if not self.type == 'entity.person':
            raise Util.exception(
                Error.DOCUMENT_INVALID_TYPE,
                {'expected': 'entity.person',
                 'current': self.type})

        # Validate that "given_name" is present in "names"
        if self.given_name not in self.names:
            raise Util.exception(
                Error.DOCUMENT_PERSON_NAMES,
                {'name': self.given_name,
                 'not_in': self.names})
        return True

    def validate(self):
        validate = True
        validate = validate if BaseDocument._validate(self) else False
        validate = validate if Document._validate(self) else False
        validate = validate if Entity._validate(self) else False
        validate = validate if Person._validate(self) else False
        return validate


class Keys(Document):
    type = StringField(value='cert.keys')
    verify = StringField()
    public = StringField()

    def _validate(self):
        # Validate that "type" is of correct type
        if not self.type == 'cert.keys':
            raise Util.exception(
                Error.DOCUMENT_INVALID_TYPE,
                {'expected': 'cert.keys',
                 'current': self.type})
        return True

    def validate(self):
        validate = True
        validate = validate if BaseDocument._validate(self) else False
        validate = validate if Document._validate(self) else False
        validate = validate if Keys._validate(self) else False
        return validate
