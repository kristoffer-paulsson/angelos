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
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Network, Host
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, FrozenPortfolioError
from angelos.portfolio.node.policy import NodePolicy
from angelos.portfolio.policy import DocumentPolicy


class NetworkCreateException(RuntimeError):
    NODES_NOT_PRESENT = ("At least one node necessary to generate network", 100)
    DOMAIN_NOT_PRESENT = ("domain necessary to generate network", 102)
    NETWORK_ALREADY_PRESENT = ("Check that there is not already a network document", 103)


class CreateNetwork(DocumentPolicy, NodePolicy, PolicyPerformer, PolicyMixin):
    """Generate network document and add to private portfolio."""

    def _setup(self):
        self._document = None

    def _clean(self):
        self._portfolio = None

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

        self._document = Network(
            nd={
                "domain": self._portfolio.domain.id,
                "hosts": hosts,
                "issuer": self._portfolio.entity.id,
            }
        )
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

    @policy(b'I', 0, "Network:Create")
    def perform(self, portfolio: PrivatePortfolio) -> Network:
        """Perform building of network."""
        self._portfolio = portfolio
        self._applier()
        return self._document
