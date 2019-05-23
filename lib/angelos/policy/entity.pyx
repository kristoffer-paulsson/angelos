# cython: language_level=3
"""Module docstring."""
import datetime

import libnacl.dual

from ..utils import Util
from .policy import Policy
from .crypto import Crypto
from ..document import Entity, PrivateKeys, Keys, Person, Ministry, Church
from ._types import EntityData, PersonData, MinistryData, ChurchData
from .portfolio import PrivatePortfolio


class BaseGeneratePolicy(Policy):
    def __init__(self):
        self.box = libnacl.dual.DualSecret()
        self.entity = None
        self.privkeys = None
        self.keys = None

    def generate(self, **kwargs):
        fields = set(self.ENTITY[0]._fields.keys())
        args = set(kwargs.keys())

        if len(args - fields):
            raise IndexError('Illegal extra fields', args - fields)

        entity = self.ENTITY[0](nd=kwargs)
        entity.issuer = entity.id
        entity.signature = self.box.signature(
            bytes(entity.issuer.bytes) + Crypto._document_data(entity))

        privkeys = PrivateKeys(nd={
            'issuer': entity.id,
            'secret': self.box.sk,
            'seed': self.box.seed
        })
        privkeys.signature = self.box.signature(
            bytes(privkeys.issuer.bytes) + Crypto._document_data(privkeys))

        keys = Keys(nd={
            'issuer': entity.id,
            'public': self.box.pk,
            'verify': self.box.vk
        })
        keys.signature = [self.box.signature(
                bytes(keys.issuer.bytes) + Crypto._document_data(keys))]

        entity.validate()
        privkeys.validate()
        keys.validate()

        self.entity = entity
        self.privkeys = privkeys
        self.keys = keys

        return True


class PersonGeneratePolicy(BaseGeneratePolicy):
    ENTITY = (Person, )


class MinistryGeneratePolicy(BaseGeneratePolicy):
    ENTITY = (Ministry, )


class ChurchGeneratePolicy(BaseGeneratePolicy):
    ENTITY = (Church, )


class BaseUpdatePolicy(Policy):
    def __init__(self):
        self.box = None
        self.entity = None
        self.privkeys = None
        self.keys = None

    def update(self, entity, privkeys, keys):
        """Renew the identity document expirey date"""
        Util.is_type(entity, self.ENTITY[0])

        today = datetime.date.today()
        # entity = copy.deepcopy(entity)
        entity.updated = today
        entity.expires = today + datetime.timedelta(13*365/12)
        entity._fields['signature'].redo = True
        entity.signature = None

        entity = Crypto.sign(entity, entity, privkeys, keys)
        entity.validate()
        self.entity = entity

        return True

    def change(self, entity, **kwargs):
        """
        Change information on the identity.
        Don't forget to update the change.
        """
        Util.is_type(entity, self.ENTITY[0])

        fields = set(self.ENTITY[1])
        args = set(kwargs.keys())

        if len(args - fields):
            raise IndexError()

        for name, field in kwargs.items():
            setattr(entity, name, field)

        return entity

    def newkeys(self, entity, privkeys, keys):
        """Issue a new pair of keys"""
        Util.is_type(entity, self.ENTITY[0])
        self.box = libnacl.dual.DualSecret()

        new_pk = PrivateKeys(nd={
            'issuer': entity.id,
            'secret': self.box.sk,
            'seed': self.box.seed
        })
        new_pk = Crypto.sign(new_pk, entity, privkeys, keys)

        new_keys = Keys(nd={
            'issuer': entity.id,
            'public': self.box.pk,
            'verify': self.box.vk
        })
        new_keys = Crypto.sign(
            new_keys, entity, privkeys, keys, multiple=True)
        new_keys = Crypto.sign(
            new_keys, entity, new_pk, new_keys, multiple=True)

        new_pk.validate()
        new_keys.validate()

        self.privkeys = new_pk
        self.keys = new_keys

        return True


class PersonUpdatePolicy(BaseUpdatePolicy):
    ENTITY = (Person, ['family_name'])


class MinistryUpdatePolicy(BaseUpdatePolicy):
    ENTITY = (Ministry, ['vision', 'ministry'])


class ChurchUpdatePolicy(BaseUpdatePolicy):
    ENTITY = (Church, ['state', 'nation'])


class BaseEntityPolicy(Policy):
    def __init__(self):
        self._box = None

    def _generate(
            self, entity_type, entity_data: EntityData) -> PrivatePortfolio:
        self._box = libnacl.dual.DualSecret()
        data = vars(entity_data)
        fields = set(type._fields.keys())
        args = set(data.keys())

        if len(args - fields):
            raise IndexError('Illegal extra fields', args - fields)

        entity = entity_type(nd=data)
        entity.issuer = entity.id
        entity.signature = self._box.signature(
            bytes(entity.issuer.bytes) + Crypto._document_data(entity))

        privkeys = PrivateKeys(nd={
            'issuer': entity.id,
            'secret': self._box.sk,
            'seed': self._box.seed
        })
        privkeys.signature = self._box.signature(
            bytes(privkeys.issuer.bytes) + Crypto._document_data(privkeys))

        keys = Keys(nd={
            'issuer': entity.id,
            'public': self._box.pk,
            'verify': self._box.vk
        })
        keys.signature = [self._box.signature(
                bytes(keys.issuer.bytes) + Crypto._document_data(keys))]

        entity.validate()
        privkeys.validate()
        keys.validate()

        return PrivatePortfolio(entity=entity, privkeys=privkeys, keys=[keys])

    def update(self, portfolio: PrivatePortfolio) -> bool:
        """Renew the identity document expiry date"""

        entity = portfolio.entity
        today = datetime.date.today()
        # entity = copy.deepcopy(entity)
        entity.updated = today
        entity.expires = today + datetime.timedelta(13*365/12)
        entity._fields['signature'].redo = True
        entity.signature = None

        entity = Crypto.sign(
            entity, portfolio.entity,
            portfolio.privkeys, portfolio.keys[0])
        entity.validate()
        portfolio.entity = entity

        return True

    def _change(self, entity: Entity, changed: dict, allowed: list) -> bool:
        """
        Change information on the identity.
        Don't forget to update the change.
        """
        fields = set(allowed)
        args = set(changed.keys())

        if len(args - fields):
            raise IndexError()

        for name, field in changed.items():
            setattr(entity, name, field)

        return True

    def newkeys(self, portfolio: PrivatePortfolio) -> bool:
        """Issue a new pair of keys"""
        self._box = libnacl.dual.DualSecret()

        new_pk = PrivateKeys(nd={
            'issuer': portfolio.entity.id,
            'secret': self._box.sk,
            'seed': self.box.seed
        })
        new_pk = Crypto.sign(
            new_pk, portfolio.entity, portfolio.privkeys, portfolio.keys[0])

        new_keys = Keys(nd={
            'issuer': portfolio.entity.id,
            'public': self._box.pk,
            'verify': self._box.vk
        })
        new_keys = Crypto.sign(
            new_keys, portfolio.entity, portfolio.privkeys,
            portfolio.keys, multiple=True)
        new_keys = Crypto.sign(
            new_keys, portfolio.entity, new_pk, new_keys, multiple=True)

        new_pk.validate()
        new_keys.validate()

        portfolio.privkeys = new_pk
        portfolio.keys.insert(0, new_keys)

        return True


class PersonPolicy(BaseEntityPolicy):
    def generate(self, person_data: PersonData) -> PrivatePortfolio:
        return self._generate(self, Person, person_data)

    def change(self, portfolio: PrivatePortfolio, changed: dict) -> bool:
        return self._change(self, portfolio.entity, changed, ['family_name'])


class MinistryPolicy(BaseEntityPolicy):
    def generate(self, ministry_data: MinistryData) -> PrivatePortfolio:
        return self._generate(self, Ministry, ministry_data)

    def change(self, portfolio: PrivatePortfolio, changed: dict) -> bool:
        return self._change(
            self, portfolio.entity, changed, ['vision', 'ministry'])


class ChurchPolicy(BaseEntityPolicy):
    def generate(self, church_data: ChurchData) -> PrivatePortfolio:
        return self._generate(self, Church, church_data)

    def change(self, portfolio: PrivatePortfolio, changed: dict) -> bool:
        return self._change(
            self, portfolio.entity, changed, ['state', 'nation'])
