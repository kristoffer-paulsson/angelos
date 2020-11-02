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
from angelos.document.domain import Node
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import Portfolio


class NodeAcceptException(RuntimeError):
    """Problems with the process that is not policy."""
    NODE_NOT_IN_PORTFOLIO = ("Node document not present in portfolio.", 100)


class BaseAcceptUpdatedNode(PolicyValidator):
    """Initialize the updated node validator."""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._node = None
        self._old = None

    def _setup(self):
        self._old = None

    def _clean(self):
        self._portfolio = None
        self._node = None


class AcceptUpdatedNodeMixin(PolicyMixin):
    """Logic for validating an updated Node for a Portfolio."""

    @policy(b'I', 0)
    def _check_node_issuer(self) -> bool:
        if self._node.issuer != self._portfolio.entity.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_node_domain(self) -> bool:
        if self._node.domain != self._portfolio.domain.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_node_expired(self) -> bool:
        if self._node.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_node_valid(self) -> bool:
        if not self._node.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_node_verify(self) -> bool:
        if not Crypto.verify(self._node, self._portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_fields_unchanged(self) -> bool:
        unchanged = set(self._node.fields()) - set(["signature", "expires", "updated"])
        same = list()
        for name in unchanged:
            same.append(getattr(self._node, name) == getattr(self._old, name))

        if not all(same):
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate updated domain with current."""
        self._old = self._portfolio.get_id(self._node.id)
        if not self._old:
            raise NodeAcceptException(*NodeAcceptException.NODE_NOT_IN_PORTFOLIO)

        if not all([
            self._check_node_issuer(),
            self._check_node_domain(),
            self._check_node_expired(),
            self._check_node_valid(),
            self._check_node_verify(),
            self._check_fields_unchanged()
        ]):
            raise PolicyException()

        docs = self._portfolio.filter({self._old}) | {self._node}
        self._portfolio.__init__(docs)
        return True


class AcceptUpdatedNode(BaseAcceptUpdatedNode, AcceptUpdatedNodeMixin):
    """Validate updated domain."""

    @policy(b'I', 0, "Node:AcceptUpdate")
    def validate(self, portfolio: Portfolio, node: Node) -> bool:
        """Perform validation of updated node for portfolio."""
        self._portfolio = portfolio
        self._node = node
        self._applier()
        return True