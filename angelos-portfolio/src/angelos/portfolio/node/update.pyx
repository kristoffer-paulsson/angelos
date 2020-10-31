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
"""Updating a node document for a portfolio."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException, PolicyValidator
from angelos.document.domain import Domain, Node
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio, FrozenPortfolioError


class NodeUpdateException(RuntimeError):
    """Problems with the process that is not policy."""
    NODE_NOT_IN_PORTFOLIO = ("Node document not present in portfolio.", 100)


class BaseUpdateNode(PolicyPerformer):
    """Initialize the node updater"""
    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._node = None

    def _setup(self):
        self._node = None

    def _clean(self):
        self._portfolio = None


class UpdateNodeMixin(PolicyMixin):
    """Logic for updating Node for a PrivatePortfolio."""

    def apply(self) -> bool:
        """Perform logic to update a node with portfolio."""
        if self._node not in self._portfolio.nodes:
            raise NodeUpdateException(*NodeUpdateException.NODE_NOT_IN_PORTFOLIO)

        self._node.renew()
        Crypto.sign(self._node, self._portfolio)
        self._node.validate()


class UpdateNode(BaseUpdateNode, UpdateNodeMixin):
    """Update node document for private portfolio."""

    @policy(b'I', 0, "Node:Update")
    def perform(self, portfolio: PrivatePortfolio, node: Node) -> Node:
        """Perform node update of private portfolio."""
        self._portfolio = portfolio
        self._node = node
        self._applier()
        return self._node
