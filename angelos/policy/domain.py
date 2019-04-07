import platform

import plyer

from .policy import Policy
from .crypto import Crypto

from ..utils import Util
from ..document.entities import Entity, PrivateKeys, Keys
from ..document.domain import Domain, Node


class NodePolicy(Policy):
    def __init__(self, entity, privkeys, keys):
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__privkeys = privkeys
        self.__keys = keys
        self.node = None

    def current(self, domain, role='client'):
        """Generate node document from currently running node"""
        Util.is_type(domain, (Domain, type(None)))
        if role not in ['client', 'server', 'backup']:
            raise IndexError()

        if domain.issuer != self.__entity.issuer:
            raise RuntimeError(
                'The domain must have same issuer as issuing entity.')

        self.node = None

        node = Node(nd={
            'domain': domain.id,
            'role': role,
            'device': platform.platform(),
            'serial': plyer.uniqueid.id,
            'issuer': self.__entity.id
        })

        node = Crypto.sign(node, self.__entity, self.__privkeys, self.__keys)
        node.validate()
        self.node = node

        return True

    def generate(self, **kwargs):
        raise NotImplementedError()

    def update(self, **kwargs):
        raise NotImplementedError()


class DomainPolicy(Policy):
    def __init__(self, entity, privkeys, keys):
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__privkeys = privkeys
        self.__keys = keys
        self.domain = None

    def generate(self):
        """Generate node document from currently running node"""
        self.domain = None

        domain = Domain(nd={
            'issuer': self.__entity.id
        })

        domain = Crypto.sign(
            domain, self.__entity, self.__privkeys, self.__keys)
        domain.validate()
        self.domain = domain

        return True

    def update(self, domain):
        raise NotImplementedError()
