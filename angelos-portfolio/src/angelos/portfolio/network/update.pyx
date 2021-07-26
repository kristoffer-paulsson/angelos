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
"""Updating an entity portfolio for Person, Ministry and Church documents."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Network, Host
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.node.policy import NodePolicy
from angelos.portfolio.policy import UpdatablePolicy


class NetworkUpdateException(RuntimeError):
    """Problems with the process that is not policy."""
    NETWORK_NOT_IN_PORTFOLIO = ("Network document not present in portfolio.", 100)
    NODES_NOT_PRESENT = ("At least one node necessary to update network", 101)
    DOMAIN_NOT_PRESENT = ("Domain necessary to update network", 102)


class UpdateNetwork(UpdatablePolicy, NodePolicy, PolicyPerformer, PolicyMixin):
    """Update network document for private portfolio."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._former = None

    def apply(self) -> bool:
        """Perform logic to update a network with its new portfolio."""
        if not self._portfolio.network:
            raise NetworkUpdateException(*NetworkUpdateException.NETWORK_NOT_IN_PORTFOLIO)

        if not self._portfolio.domain:
            raise NetworkUpdateException(*NetworkUpdateException.DOMAIN_NOT_PRESENT)

        if not self._portfolio.nodes:
            raise NetworkUpdateException(*NetworkUpdateException.NODES_NOT_PRESENT)

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

        self._document.hosts = hosts
        self._document.renew()
        Crypto.sign(self._document, self._portfolio)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_domain_issuer(),
            self._check_node_domain(),
            self._check_fields_unchanged() if self._former else True
        ]):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Network:Update")
    def perform(self, portfolio: PrivatePortfolio) -> Network:
        """Perform network update of private portfolio."""
        self._portfolio = portfolio
        self._former = portfolio.network
        self._document = portfolio.network
        self._applier()
        return self._document