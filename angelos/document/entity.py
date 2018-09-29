import datetime

from .model import BaseDocument
from .document import Document
from .model import DateField, StringField, ChoiceField


class Entity(Document):
    updated = DateField(required=False)

    def _validate(self):
        validate = True

        # Validate that "expires" is at least 13 months in the future compared
        # to "updated"
        if bool(self.updated):
            if not (self.expires - self.updated >=
                    datetime.timedelta(13*365/12)):
                validate = False

        return validate


class VirtualPerson(Entity):
    founded = DateField()


class Church(VirtualPerson):
    type = StringField(value='entity.church')
    nation = StringField()
    state = StringField(required=False)
    city = StringField()


class Ministry(VirtualPerson):
    type = StringField(value='entity.ministry')
    ministry = StringField()
    vision = StringField()


class Person(Entity):
    type = StringField(value='entity.person')
    given_name = StringField()
    family_name = StringField()
    names = StringField(multiple=True)
    born = DateField()
    gender = ChoiceField(choices=['man', 'woman', 'undefined'])

    def _validate(self):
        validate = True

        # Validate that "type" is of correct type
        if not self.type == 'entity.person':
            validate = False

        # Validate that "given_name" is present in "names"
        if self.given_name not in self.names:
            validate = False

        return validate

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
        validate = True

        # Validate that "type" is of correct type
        if not self.type == 'cert.keys':
            validate = False

        return validate

    def validate(self):
        validate = True
        validate = validate if BaseDocument._validate(self) else False
        validate = validate if Document._validate(self) else False
        validate = validate if Keys._validate(self) else False
        return validate
