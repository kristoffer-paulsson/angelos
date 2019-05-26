# cython: language_level=3
"""Policy classes for Domain and Nodes."""
import platform
import ipaddress

import plyer

from ._types import PrivatePortfolioABC
from .policy import Policy
from .crypto import Crypto

from ..const import Const
from ..document.domain import Domain, Node, Location, Network, Host
from ..automatic import Net


class NodePolicy(Policy):
    """Generate node documents."""

    ROLE = ('client', 'server', 'backup')

    @staticmethod
    def current(
            portfolio: PrivatePortfolioABC,
            role: str='client', server: bool=False):
        """Generate node document from the current node."""

        if isinstance(role, int):
            if role == Const.A_ROLE_PRIMARY:
                role = 'server'
            elif role == Const.A_ROLE_BACKUP:
                role = 'backup'

        if role not in NodePolicy.ROLE:
            raise ValueError('Unsupported node role')

        if portfolio.domain.issuer != portfolio.entity.issuer:
            raise RuntimeError(
                'The domain must have same issuer as issuing entity.')

        location = None
        if server:
            net = Net()
            location = Location(nd={
                'hostname': [net.domain],
                'ip': [ipaddress.ip_address(net.ip)]
            })

        node = Node(nd={
            'domain': portfolio.domain.id,
            'role': role,
            'device': platform.platform(),
            'serial': plyer.uniqueid.id.decode('utf-8'),
            'issuer': portfolio.entity.id,
            'location': location
        })

        node = Crypto.sign(node, portfolio.entity,
                           portfolio.privkeys, next(iter(portfolio.keys)))
        node.validate()
        portfolio.nodes.add(node)

        return True

    def generate(self, **kwargs):
        raise NotImplementedError()

    def update(self, **kwargs):
        raise NotImplementedError()


class DomainPolicy(Policy):

    @staticmethod
    def generate(portfolio: PrivatePortfolioABC):
        """Generate domain document from currently running node."""
        if portfolio.domain:
            return False

        domain = Domain(nd={
            'issuer': portfolio.entity.id
        })

        domain = Crypto.sign(
            domain, portfolio.entity,
            portfolio.privkeys, next(iter(portfolio.keys)))
        domain.validate()
        portfolio.domain = domain

        return True

    def update(self, domain):
        raise NotImplementedError()


class NetworkPolicy(Policy):

    @staticmethod
    def generate(portfolio: PrivatePortfolioABC):
        """Generate network document from currently running node."""
        if not portfolio.nodes:
            raise ValueError('At least one node necessary to generate network')

        hosts = []
        for node in portfolio.nodes:
            hosts.append(Host(nd={
                'node': node.id,
                'ip': node.location.ip,
                'hostname': node.location.hostname
            }))

        network = Network(nd={
            'domain': portfolio.domain.id,
            'hosts': hosts,
            'issuer': portfolio.entity.id,
        })

        network = Crypto.sign(
            network, portfolio.entity,
            portfolio.privkeys, next(iter(portfolio.keys)))
        network.validate()
        portfolio.network = network

        return True

    def update(self, domain):
        raise NotImplementedError()
