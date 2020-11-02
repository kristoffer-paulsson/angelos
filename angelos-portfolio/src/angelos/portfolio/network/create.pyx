# cython: language_level=3
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
"""Creating new domain document for new portfolio."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy
from angelos.document.domain import Network, Host
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, FrozenPortfolioError


class NetworkCreateException(RuntimeError):
    NODES_NOT_PRESENT = ("At least one node necessary to generate network", 100)
    DOMAIN_NOT_PRESENT = ("domain necessary to generate network", 102)
    NETWORK_ALREADY_PRESENT = ("Check that there is not already a network document", 103)


class BaseCreateNetwork(PolicyPerformer):
    """Initialize the network generator"""
    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._network = None

    def _setup(self):
        self._network = None

    def _clean(self):
        self._portfolio = None


class CreateNetworkMixin(PolicyMixin):
    """Logic for generating Network for a new PrivatePortfolio."""

    def apply(self) -> bool:
        """Perform logic to create a new network with portfolio."""
        if self._portfolio.is_frozen():
            raise FrozenPortfolioError()

        if self._portfolio.network:
            raise NetworkCreateException(*NetworkCreateException.NETWORK_ALREADY_PRESENT)

        if not self._portfolio.domain:
            raise NetworkCreateException(*NetworkCreateException.DOMAIN_NOT_PRESENT)

        if not self._portfolio.nodes:
            raise NetworkCreateException(*NetworkCreateException.NODES_NOT_PRESENT)

        hosts = list()
        for node in self._portfolio.nodes:
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

        self._network = Network(
            nd={
                "domain": self._portfolio.domain.id,
                "hosts": hosts,
                "issuer": self._portfolio.entity.id,
            }
        )

        self._network = Crypto.sign(self._network, self._portfolio)
        self._network.validate()
        self._portfolio.documents().add(self._network)


class CreateNetwork(BaseCreateNetwork, CreateNetworkMixin):
    """Generate network document and add to private portfolio."""

    @policy(b'I', 0, "Network:Create")
    def perform(self, portfolio: PrivatePortfolio) -> Network:
        """Perform building of network."""
        self._portfolio = portfolio
        self._applier()
        return self._network
