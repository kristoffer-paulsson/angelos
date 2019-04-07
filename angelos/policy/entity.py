import datetime

import libnacl.dual

from ..utils import Util
from .policy import Policy
from .crypto import Crypto
from ..document.entities import PrivateKeys, Keys, Person, Ministry, Church


class BaseGeneratePolicy(Policy):
    def __init__(self):
        self.box = libnacl.dual.DualSecret()
        self.entity = None
        self.private = None
        self.keys = None

    def generate(self, **kwargs):
        fields = set(self.ENTITY[0]._fields.keys())
        args = set(kwargs.keys())

        if len(args - fields):
            raise IndexError()

        entity = self.ENTITY[0](nd=kwargs)
        entity.issuer = entity.id
        entity.signature = self.box.signature(
            bytes(entity.issuer.bytes) + Crypto._docdata(entity))

        private = PrivateKeys(nd={
            'issuer': entity.id,
            'secret': self.box.sk,
            'seed': self.box.seed
        })
        private.signature = self.box.signature(
            bytes(private.issuer.bytes) + Crypto._docdata(private))

        keys = Keys(nd={
            'issuer': entity.id,
            'public': self.box.pk,
            'verify': self.box.vk
        })
        keys.signature = [self.box.signature(
                bytes(keys.issuer.bytes) + Crypto._docdata(keys))]

        entity.validate()
        private.validate()
        keys.validate()

        self.entity = entity
        self.private = private
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
        self.private = None
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

        private = PrivateKeys(nd={
            'issuer': entity.id,
            'secret': self.box.sk,
            'seed': self.box.seed
        })
        new_pk = Crypto.sign(private, entity, privkeys, keys)

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

        self.private = new_pk
        self.keys = new_keys

        return True


class PersonUpdatePolicy(BaseUpdatePolicy):
    ENTITY = (Person, ['family_name'])


class MinistryUpdatePolicy(BaseUpdatePolicy):
    ENTITY = (Ministry, ['vision', 'ministry'])


class ChurchUpdatePolicy(BaseUpdatePolicy):
    ENTITY = (Church, ['state', 'nation'])
