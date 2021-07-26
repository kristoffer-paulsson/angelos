
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
from angelos.document.domain import Node
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.node.policy import NodePolicy
from angelos.portfolio.policy import UpdatablePolicy, DocumentPolicy


class NodeUpdateException(RuntimeError):
    """Problems with the process that is not policy."""
    NODE_NOT_IN_PORTFOLIO = ("Node document not present in portfolio.", 100)
    DOMAIN_NOT_IN_PORTFOLIO = ("Domain not present in portfolio.", 101)
    NODE_ALREADY_PORTFOLIO = ("Node already present in portfolio.", 102)


class AcceptNode(DocumentPolicy, NodePolicy, PolicyMixin, PolicyValidator):
    """Accept node."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None

    def apply(self) -> bool:
        """Perform logic to validate node with current."""

        if self._document in self._portfolio.nodes:
            raise NodeUpdateException(*NodeUpdateException.NODE_ALREADY_PORTFOLIO)

        if not self._portfolio.domain:
            raise NodeUpdateException(*NodeUpdateException.DOMAIN_NOT_IN_PORTFOLIO)

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
        return True

    @policy(b'I', 0, "Node:Accept")
    def validate(self, portfolio: PrivatePortfolio, node: Node) -> bool:
        """Perform validation of node for portfolio."""
        self._portfolio = portfolio
        self._document = node
        self._applier()
        return True


class AcceptUpdatedNode(UpdatablePolicy, NodePolicy, PolicyMixin, PolicyValidator):
    """Accept updated node."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None
        self._former = None

    def apply(self) -> bool:
        """Perform logic to accept updated node with current."""
        if self._document not in self._portfolio.nodes:
            raise NodeUpdateException(*NodeUpdateException.NODE_NOT_IN_PORTFOLIO)

        if not self._portfolio.domain:
            raise NodeUpdateException(*NodeUpdateException.DOMAIN_NOT_IN_PORTFOLIO)

        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_domain_issuer(),
            self._check_node_domain(),
            self._check_fields_unchanged()
        ]):
            raise PolicyException()

        self._update()
        return True

    @policy(b'I', 0, "Node:ValidatePrivate")
    def validate(self, portfolio: PrivatePortfolio, node: Node) -> bool:
        """Perform accept of updated node for portfolio."""
        self._portfolio = portfolio
        self._document = node
        self._former = portfolio.get_id(node.id)
        self._applier()
        return True