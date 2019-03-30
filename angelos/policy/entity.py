import base64

import libnacl.dual

from .policy import Policy
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

        if len(args - fields): raise IndexError()  # noqa E701

        entity = self.ENTITY[0](nd=kwargs)
        entity.issuer = entity.id
        entity.signature = base64.standard_b64encode(
            self.box.signature(
                bytes(entity.id.bytes) + self._docdata(entity)))
        private = PrivateKeys(nd={
            'issuer': entity.id,
            'secret': self.box.hex_sk(),
            'seed': self.box.hex_seed()
        })
        private.signature = base64.standard_b64encode(
            self.box.signature(
                bytes(entity.id.bytes) + self._docdata(private)))

        keys = Keys(nd={
            'issuer': entity.id,
            'public': self.box.hex_pk(),
            'verify': self.box.hex_vk()
        })
        keys.signature = base64.standard_b64encode(
            self.box.signature(
                bytes(entity.id.bytes) + self._docdata(keys)))

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


class PersonUpdatePolicy(Policy):
    def update(self):
        pass

    def change(self):
        pass

    def keys(self):
        pass


class MinistryUpdatePolicy(Policy):
    def update(self):
        pass


class ChuchUpdatePolicy(Policy):
    def update(self):
        pass
