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
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.policy import DocumentPolicy, UpdatablePolicy


class BaseValidateNode(PolicyValidator):
    """Initialize the updated node validator."""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._document = None
        self._former = None

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None
        self._former = None


class ValidateNodeMixin(DocumentPolicy, UpdatablePolicy, PolicyMixin):
    """Logic for validating an updated Node for a Portfolio."""

    @policy(b'I', 0)
    def _check_node_domain(self) -> bool:
        if self._document.domain != self._portfolio.domain.id:
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate updated domain with current."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_node_domain() if self._portfolio.domain else True,
            self._check_fields_unchanged() if self._former else True
        ]):
            raise PolicyException()
        return True


class ValidateNode(BaseValidateNode, ValidateNodeMixin):
    """Validate updated domain."""

    @policy(b'I', 0, "Node:ValidatePrivatePortfolio")
    def validate(self, portfolio: PrivatePortfolio, node: Node) -> bool:
        """Perform validation of updated node for portfolio."""
        self._portfolio = portfolio
        self._document = node
        self._former = portfolio.get_id(node)
        self._applier()
        return True