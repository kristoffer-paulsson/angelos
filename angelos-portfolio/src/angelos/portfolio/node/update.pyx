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
"""Updating a node document for a portfolio."""
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.domain import Node
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.node.policy import NodePolicy
from angelos.portfolio.policy import UpdatablePolicy


class NodeUpdateException(RuntimeError):
    """Problems with the process that is not policy."""
    NODE_NOT_IN_PORTFOLIO = ("Node document not present in portfolio.", 100)
    DOMAIN_NOT_IN_PORTFOLIO = ("Domain not present in portfolio.", 101)


class UpdateNode(UpdatablePolicy, NodePolicy, PolicyPerformer, PolicyMixin):
    """Update node document for private portfolio."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None

    def apply(self) -> bool:
        """Perform logic to update a node with portfolio."""
        if self._document not in self._portfolio.nodes:
            raise NodeUpdateException(*NodeUpdateException.NODE_NOT_IN_PORTFOLIO)

        if not self._portfolio.domain:
            raise NodeUpdateException(*NodeUpdateException.DOMAIN_NOT_IN_PORTFOLIO)

        self._former = self._document
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

    @policy(b'I', 0, "Node:Update")
    def perform(self, portfolio: PrivatePortfolio, node: Node) -> Node:
        """Perform node update of private portfolio."""
        self._portfolio = portfolio
        self._document = node
        self._applier()
        return self._document
