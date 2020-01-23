# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Policy classes for Domain and Nodes."""
import ipaddress
import platform

from libangelos.automatic import Net
from libangelos.const import Const
from libangelos.document.domain import Domain, Node, Location, Network, Host
from libangelos.misc import Misc
from libangelos.policy.crypto import Crypto
from libangelos.policy.policy import Policy
from libangelos.policy.types import PrivatePortfolioABC, Union


class NodePolicy(Policy):
    """Generate node documents."""

    ROLE = ("client", "server", "backup")

    @staticmethod
    def current(
        portfolio: PrivatePortfolioABC,
        role: int = Const.A_ROLE_PRIMARY,
        server: bool = False,
        ip: Union[ipaddress.IPv4Address, ipaddress.IPv6Address] = None
    ):
        """Generate node document from the current node."""

        if role == Const.A_ROLE_BACKUP:
            role = "backup"
        else:
            if server:
                role = "server"
            else:
                role = "client"

        if portfolio.domain.issuer != portfolio.entity.issuer:
            raise RuntimeError(
                "The domain must have same issuer as issuing entity."
            )

        location = None
        if server:
            net = Net()
            location = Location(
                nd={
                    "hostname": [net.domain],
                    "ip": [ip if ip else ipaddress.ip_address(net.ip) if net.ip else None],
                }
            )

        node = Node(
            nd={
                "domain": portfolio.domain.id,
                "role": role,
                "device": platform.platform(),
                "serial": Misc.unique(),
                "issuer": portfolio.entity.id,
                "location": location,
            }
        )

        node = Crypto.sign(node, portfolio)
        node.validate()
        portfolio.nodes.add(node)

        return True

    def generate(self, **kwargs):
        raise NotImplementedError()

    def update(self, portfolio: PrivatePortfolioABC, node: Node) -> bool:
        if node in portfolio.nodes:
            portfolio.nodes.remove(node)

        node.renew()

        node = Crypto.sign(node, portfolio)
        node.validate()
        portfolio.nodes.add(node)

        return True


class DomainPolicy(Policy):
    @staticmethod
    def generate(portfolio: PrivatePortfolioABC):
        """Generate domain document from currently running node."""
        if portfolio.domain:
            return False

        domain = Domain(nd={"issuer": portfolio.entity.id})

        domain = Crypto.sign(domain, portfolio)
        domain.validate()
        portfolio.domain = domain

        return True

    def update(self, portfolio: PrivatePortfolioABC, domain: Domain) -> bool:
        if portfolio.domain:
            portfolio.domain = None

        domain.renew()

        domain = Crypto.sign(domain, portfolio)
        domain.validate()
        portfolio.domain = domain

        return True


class NetworkPolicy(Policy):
    @staticmethod
    def generate(portfolio: PrivatePortfolioABC):
        """Generate network document from currently running node."""
        if not portfolio.nodes:
            raise ValueError("At least one node necessary to generate network")

        hosts = []
        for node in portfolio.nodes:
            if node.role == "server":
                hosts.append(
                    Host(
                        nd={
                            "node": node.id,
                            "ip": node.location.ip,
                            "hostname": node.location.hostname,
                        }
                    )
                )

        network = Network(
            nd={
                "domain": portfolio.domain.id,
                "hosts": hosts,
                "issuer": portfolio.entity.id,
            }
        )

        network = Crypto.sign(network, portfolio)
        network.validate()
        portfolio.network = network

        return True

    def update(self, portfolio: PrivatePortfolioABC, network: Network) -> bool:
        if network in portfolio.network:
            portfolio.network = None

        if not portfolio.nodes:
            raise ValueError("At least one node necessary to renew network")

        hosts = []
        for node in portfolio.nodes:
            hosts.append(
                Host(
                    nd={
                        "node": node.id,
                        "ip": node.location.ip,
                        "hostname": node.location.hostname,
                    }
                )
            )

        network.hosts = hosts
        network.renew()

        network = Crypto.sign(network, portfolio)
        network.validate()
        portfolio.network = network

        return True
