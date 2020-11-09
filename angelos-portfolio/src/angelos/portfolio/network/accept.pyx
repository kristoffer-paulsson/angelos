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
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.policy import UpdatablePolicy, DocumentPolicy


class NetworkAcceptException(RuntimeError):
    """Problems with the process that is not policy."""
    NETWORK_ALREADY_IN_PORTFOLIO = ("Network document already present in portfolio.", 100)
    NETWORK_NOT_IN_PORTFOLIO = ("Network document not present in portfolio.", 101)


class AcceptNetwork(DocumentPolicy, PolicyValidator, PolicyMixin):
    """Validate network."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None

    def apply(self) -> bool:
        """Perform logic to validate network for current."""
        if self._portfolio.network:
            raise NetworkAcceptException(*NetworkAcceptException.NETWORK_ALREADY_IN_PORTFOLIO)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify()
        ]):
            raise PolicyException()

        self._add()
        return True

    @policy(b'I', 0, "Network:Accept")
    def validate(self, portfolio: Portfolio, network: Network) -> bool:
        """Perform validation of network for portfolio."""
        self._portfolio = portfolio
        self._document = network
        self._applier()
        return True


class AcceptUpdatedNetwork(UpdatablePolicy, PolicyValidator, PolicyMixin):
    """Validate updated network."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None
        self._former = None

    def apply(self) -> bool:
        """Perform logic to validate updated network with current."""
        if not self._portfolio.network:
            raise NetworkAcceptException(*NetworkAcceptException.NETWORK_NOT_IN_PORTFOLIO)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_fields_unchanged()
        ]):
            raise PolicyException()

        self._update()
        return True

    @policy(b'I', 0, "Network:AcceptUpdated")
    def validate(self, portfolio: Portfolio, network: Network) -> bool:
        """Perform validation of updated network for portfolio."""
        self._portfolio = portfolio
        self._document = network
        self._former = portfolio.get_id(network.id)
        self._applier()
        return True