import types
from ..utils import Util
from .model import BaseDocument
from .issuance import IssuerMixin, IssueMixin

Entity = type(
    'Entity', (BaseDocument, IssuerMixin, IssueMixin), {
        'updated': None, **IssuerMixin.properties(), **IssueMixin.properties()
        })

VirtualPerson = type(
    'VirtualPerson', (Entity, ), {'founded': None})

Church = type(
    'Church', (VirtualPerson, ), {
        'nation': None, 'state': None, 'city': None})

Ministry = type(
    'Ministry', (VirtualPerson, ), {
        'ministry': None, 'vision': None})

Person = type(
    'Person', (Entity), {
        'given_name': None, 'family_name': None, 'names': [], 'born': None,
        'gender': None})


class EntityFactory:
    @staticmethod
    def church(city, nation, founded, state=None):
        Util.is_type(city, str)
        Util.is_type(nation, str)
        Util.is_type(state, (str, types.NoneType))
        Util.is_type(founded, str)
        c = {
            'updated': None,
            'type': 'entity.church',
            'city': city,
            'state': state,
            'nation': nation,
            'founded': founded,
        }
        return Church(c)

    @staticmethod
    def ministry(ministry, vision, founded):
        Util.is_type(ministry, str)
        Util.is_type(vision, str)
        Util.is_type(founded, str)
        m = {
            'updated': None,
            'type': 'entity.ministry',
            'ministry': ministry,
            'vision': vision,
            'founded': founded,
        }
        return Ministry(m)

    @staticmethod
    def person(given_name, family_name, names, born, gender):
        Util.is_type(given_name, str)
        Util.is_type(family_name, str)
        Util.is_type(names, list)
        Util.is_type(born, str)
        Util.is_type(gender, str)
        p = {
            'updated': None,
            'type': 'entity.ministry',
            'given_name': given_name,
            'family_name': family_name,
            'names': names,
            'born': born,
            'gender': gender,
        }
        return Person(p)
