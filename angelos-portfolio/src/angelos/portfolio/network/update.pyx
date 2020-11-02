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
"""Updating an entity portfolio for Person, Ministry and Church documents."""
from typing import Any

from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Network, Host
from angelos.document.entities import Person, Ministry, Church
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.portfolio.collection import PrivatePortfolio


class NetworkUpdateException(RuntimeError):
    """Problems with the process that is not policy."""
    NETWORK_NOT_IN_PORTFOLIO = ("Network document not present in portfolio.", 100)
    NODES_NOT_PRESENT = ("At least one node necessary to update network", 101)
    DOMAIN_NOT_PRESENT = ("Domain necessary to update network", 102)


class BaseUpdateNetwork(PolicyPerformer):
    """Initialize the network updater."""
    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._network = None
        self._changeables = None

    def _setup(self):
        pass

    def _clean(self):
        pass


class UpdateNetworkMixin(PolicyMixin):
    """Logic for updating Network in an existing PrivatePortfolio."""

    @policy(b'I', 0)
    def _check_field_update(self, name: str, field: Any) -> bool:
        if name in self._changeables:
            setattr(self._network, name, field)
        elif getattr(self._network, name, None) != field:
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to update a network with its new portfolio."""
        self._network = self._portfolio.network
        if not self._network:
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

        self._network.hosts = hosts
        self._network.renew()
        Crypto.sign(self._network, self._portfolio)
        return self._network.validate()


class UpdateNetwork(BaseUpdateNetwork, UpdateNetworkMixin):
    """Update network document for private portfolio."""

    @policy(b'I', 0, "Network:Update")
    def perform(self, portfolio: PrivatePortfolio) -> Network:
        """Perform network update of private portfolio."""
        self._portfolio = portfolio
        self._applier()
        return self._network