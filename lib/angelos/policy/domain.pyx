# cython: language_level=3
"""Policy classes for Domain and Nodes."""
import platform
import ipaddress

import plyer

from .policy import Policy
from .crypto import Crypto

from ..utils import Util
from ..const import Const
from ..document.entities import Entity, PrivateKeys, Keys
from ..document.domain import Domain, Node, Location, Network, Host
from ..automatic import Automatic


class NodePolicy(Policy):
    """Generate node documents."""

    ROLE = ('client', 'server', 'backup')

    def __init__(self, entity, privkeys, keys):
        """Init with Entity, PrivateKeys and Keys."""
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__privkeys = privkeys
        self.__keys = keys
        self.node = None

    def current(self, domain, role='client', server=False):
        """Generate node document from the current node."""
        Util.is_type(domain, Domain)
        Util.is_type(role, (str, int, type(None)))
        Util.is_type(server, (bool, type(None)))

        self.node = None

        if isinstance(role, int):
            if role == Const.A_ROLE_PRIMARY:
                role = 'server'
            elif role == Const.A_ROLE_BACKUP:
                role = 'backup'

        if role not in NodePolicy.ROLE:
            raise ValueError('Unsupported node role')

        if domain.issuer != self.__entity.issuer:
            raise RuntimeError(
                'The domain must have same issuer as issuing entity.')

        location = None
        if server:
            auto = Automatic()
            location = Location(nd={
                'hostname': [auto.net.domain],
                'ip': [ipaddress.ip_address(auto.net.ip)]
            })

        node = Node(nd={
            'domain': domain.id,
            'role': role,
            'device': platform.platform(),
            'serial': plyer.uniqueid.id.decode('utf-8'),
            'issuer': self.__entity.id,
            'location': location
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
        """Generate domain document from currently running node."""
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


class NetworkPolicy(Policy):
    def __init__(self, entity, privkeys, keys):
        Util.is_type(entity, Entity)
        Util.is_type(privkeys, PrivateKeys)
        Util.is_type(keys, Keys)

        self.__entity = entity
        self.__privkeys = privkeys
        self.__keys = keys
        self.network = None

    def generate(self, domain, *nodes):
        """Generate network document from currently running node."""
        Util.is_type(domain, Domain)
        for node in nodes:
            Util.is_type(node, Node)

        hosts = []
        for node in nodes:
            hosts.append(Host(nd={
                'node': node.id,
                'ip': node.location.ip,
                'hostname': node.location.hostname
            }))

        network = Network(nd={
            'domain': domain.id,
            'hosts': hosts,
            'issuer': self.__entity.id,
        })

        network = Crypto.sign(
            network, self.__entity, self.__privkeys, self.__keys)
        network.validate()
        self.network = network

        return True

    def update(self, domain):
        raise NotImplementedError()
