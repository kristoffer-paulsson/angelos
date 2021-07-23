# cython: language_level=3, linetrace=True
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Policy classes for Domain and Nodes."""
import ipaddress
import platform
from typing import Union

from angelos.lib.automatic import Network as AutoNet
from angelos.lib.const import Const
from angelos.document.domain import Domain, Node, Location, Network, Host
from angelos.common.misc import Misc
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.policy import Policy
from angelos.portfolio.collection import PrivatePortfolio


class NodePolicy(Policy):
    """Generate node documents."""

    ROLE = ("client", "server", "backup")

    @staticmethod
    def current(
        portfolio: PrivatePortfolio,
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
            net = AutoNet()
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

    def update(self, portfolio: PrivatePortfolio, node: Node) -> bool:
        if node in portfolio.nodes:
            portfolio.nodes.remove(node)

        node.renew()

        node = Crypto.sign(node, portfolio)
        node.validate()
        portfolio.nodes.add(node)

        return True


class DomainPolicy(Policy):
    @staticmethod
    def generate(portfolio: PrivatePortfolio):
        """Generate domain document from currently running node."""
        if portfolio.domain:
            return False

        domain = Domain(nd={"issuer": portfolio.entity.id})

        domain = Crypto.sign(domain, portfolio)
        domain.validate()
        portfolio.domain = domain

        return True

    def update(self, portfolio: PrivatePortfolio, domain: Domain) -> bool:
        if portfolio.domain:
            portfolio.domain = None

        domain.renew()

        domain = Crypto.sign(domain, portfolio)
        domain.validate()
        portfolio.domain = domain

        return True


class NetworkPolicy(Policy):
    @staticmethod
    def generate(portfolio: PrivatePortfolio):
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

    def update(self, portfolio: PrivatePortfolio, network: Network) -> bool:
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