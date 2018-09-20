from .document import Document
from .model import DateField, StringField, ChoiceField


class Entity(Document):
    updated = DateField(required=False)


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


class Keys(Document):
    type = StringField(value='cert.keys')
    verify = StringField()
    public = StringField()
