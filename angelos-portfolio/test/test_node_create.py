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
"""Security tests putting the policies to the test."""
from unittest import TestCase

from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData
from angelos.meta.fake import Generate
from angelos.portfolio.collection import FrozenPortfolioError
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.entity.create import CreatePersonEntity
from angelos.portfolio.node.create import CreateNode, NodeCreateException


class TestCreateNode(TestCase):
    def test_current(self):
        data = PersonData(**Generate.person_data()[0])
        portfolio = CreatePersonEntity().perform(data)

        with self.assertRaises(NodeCreateException):
            CreateNode().current(portfolio, server=True)

        CreateDomain().perform(portfolio)
        with evaluate("Node:Create") as report:
            node = CreateNode().current(portfolio, server=True)
            self.assertIsNotNone(node)
            self.assertIn(node, portfolio.nodes)
        self.assertTrue(report)

        portfolio.freeze()
        with self.assertRaises(FrozenPortfolioError):
            CreateNode().current(portfolio, server=True)
