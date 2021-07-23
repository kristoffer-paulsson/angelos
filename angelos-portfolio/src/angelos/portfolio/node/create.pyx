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
from ipaddress import IPv4Address, IPv6Address, ip_address
from typing import Union
from urllib.parse import urlparse, urlunparse

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Location, Node
from angelos.lib.const import Const
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, FrozenPortfolioError
from angelos.portfolio.node.policy import NodePolicy
from angelos.portfolio.policy import DocumentPolicy


class NodeCreateException(RuntimeError):
    DOMAIN_NOT_IN_PORTFOLIO = ("Domain not present in portfolio.", 100)


class CreateNode(DocumentPolicy, NodePolicy, PolicyPerformer, PolicyMixin):
    """Generate node document and add to private portfolio."""

    def __init__(self):
        super().__init__()
        self._device = Node
        self._serial = Node
        self._role = None
        self._server = None
        self._ip = None
        self._hostname = None

    def _setup(self):
        self._document = None

    def _clean(self):
        pass

    def apply(self) -> bool:
        """Perform logic to create a new node with new portfolio."""
        if self._portfolio.is_frozen():
            raise FrozenPortfolioError()

        if not self._portfolio.domain:
            raise NodeCreateException(*NodeCreateException.DOMAIN_NOT_IN_PORTFOLIO)

        if self._role == Const.A_ROLE_BACKUP:
            self._role = "backup"
        else:
            if self._server:
                role = "server"
            else:
                role = "client"

        hostname = urlunparse(urlparse(self._hostname)[:2] + ("", "", "", ""))
        location = None
        if self._server:
            location = Location(nd={
                "hostname": [hostname] if hostname else [],
                "ip": [self._ip]
            })

        self._document = Node(nd={
            "domain": self._portfolio.domain.id,
            "role": role,
            "device": self._device,
            "serial": self._serial,
            "issuer": self._portfolio.entity.id,
            "location": location
        })
        self._document = Crypto.sign(self._document, self._portfolio)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_domain_issuer(),
            self._check_node_domain()
        ]):
            raise PolicyException()

        self._add()

    @policy(b'I', 0, "Node:Create")
    def perform(
            self, portfolio: PrivatePortfolio, device: str, serial: str, ip: Union[IPv4Address, IPv6Address] = None,
            hostname: str = None, role: int=Const.A_ROLE_PRIMARY, server: bool = False
    ) -> Node:
        """Perform building of person portfolio."""
        self._portfolio = portfolio
        self._device = device
        self._serial = serial
        self._ip = ip
        self._hostname = hostname
        self._role = role
        self._server = server

        self._applier()
        return self._document

    def current(self, portfolio: PrivatePortfolio, ip: Union[IPv4Address, IPv6Address] = None,
            hostname: str = None, role: int = Const.A_ROLE_PRIMARY, server: bool = False) -> Node:
        """Generate node from current device and system configuration."""
        import platform
        from angelos.common.misc import Misc
        from angelos.lib.automatic import Network
        net = Network()

        return self.perform(
            portfolio, platform.platform(), Misc.unique(),
            ip if ip else ip_address(net.ip),
            hostname if hostname else net.domain,
            role, server
        )