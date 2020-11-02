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
"""Creating new entity portfolio for Person, Ministry and Church including Keys and PrivateKeys documents."""
from angelos.common.policy import PolicyMixin, policy, PolicyException, PolicyValidator
from angelos.document.domain import Network
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import Portfolio


class NetworkAcceptException(RuntimeError):
    """Problems with the process that is not policy."""
    NETWORK_ALREADY_IN_PORTFOLIO = ("Network document already present in portfolio.", 100)
    NETWORK_NOT_IN_PORTFOLIO = ("Network document not present in portfolio.", 101)


class BaseAcceptNetwork(PolicyValidator):
    """Initialize the network validator."""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._network = None

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._network = None


class AcceptNetworkChecker:
    """Common policy checkers for network accept."""

    @policy(b'I', 0)
    def _check_network_issuer(self) -> bool:
        if self._network.issuer != self._portfolio.entity.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_network_expired(self) -> bool:
        if self._network.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_network_valid(self) -> bool:
        if not self._network.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_network_verify(self) -> bool:
        if not Crypto.verify(self._network, self._portfolio):
            raise PolicyException()
        return True


class AcceptNetworkMixin(AcceptNetworkChecker, PolicyMixin):
    """Logic for validating a Network for a Portfolio."""

    def apply(self) -> bool:
        """Perform logic to validate network for current."""
        if self._portfolio.network:
            raise NetworkAcceptException(*NetworkAcceptException.NETWORK_ALREADY_PORTFOLIO)

        if not all([
            self._check_node_issuer(),
            self._check_node_domain(),
            self._check_node_expired(),
            self._check_node_valid(),
            self._check_node_verify(),
        ]):
            raise PolicyException()

        docs = self._portfolio.documents() | {self._network}
        self._portfolio.__init__(docs)
        return True


class AcceptNetwork(BaseAcceptNetwork, AcceptNetworkMixin):
    """Validate network."""

    @policy(b'I', 0, "Network:Accept")
    def validate(self, portfolio: Portfolio, network: Network) -> bool:
        """Perform validation of network for portfolio."""
        self._portfolio = portfolio
        self._network = network
        self._applier()
        return True


class AcceptUpdatedNetworkMixin(AcceptNetworkChecker, PolicyMixin):
    """Logic for validating an updated Network for a Portfolio."""

    @policy(b'I', 0)
    def _check_fields_unchanged(self) -> bool:
        unchanged = set(self._network.fields()) - set(["signature", "expires", "updated", "hosts"])
        same = list()
        for name in unchanged:
            same.append(getattr(self._network, name) == getattr(self._portfolio.network, name))

        if not all(same):
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate updated network with current."""
        if not self._portfolio.network:
            raise NetworkAcceptException(*NetworkAcceptException.NETWORK_NOT_IN_PORTFOLIO)

        if not all([
            self._check_node_issuer(),
            self._check_node_domain(),
            self._check_node_expired(),
            self._check_node_valid(),
            self._check_node_verify(),
            self._check_fields_unchanged()
        ]):
            raise PolicyException()

        docs = self._portfolio.filter({self._portfolio.network}) | {self._network}
        self._portfolio.__init__(docs)
        return True


class AcceptUpdatedNetwork(BaseAcceptNetwork, AcceptUpdatedNetworkMixin):
    """Validate updated network."""

    @policy(b'I', 0, "Network:AcceptUpdate")
    def validate(self, portfolio: Portfolio, network: Network) -> bool:
        """Perform validation of updated network for portfolio."""
        self._portfolio = portfolio
        self._network = network
        self._applier()
        return True