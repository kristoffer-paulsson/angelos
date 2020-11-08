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
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.entity.create import CreatePersonEntity
from angelos.portfolio.node.create import CreateNode

from angelos.portfolio.node.update import UpdateNode
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio

from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData
from angelos.meta.fake import Generate

from unittest import TestCase


class TestUpdateNode(TestCase):
    def test_perform(self):
        data = PersonData(**Generate.person_data()[0])
        portfolio = CreatePersonEntity().perform(data)
        CreateDomain().perform(portfolio)
        node = CreateNode().current(portfolio, server=True)

        self.assertIsNotNone(portfolio.domain)
        with evaluate("Node:Update") as report:
            node = UpdateNode().perform(portfolio, node)
            self.assertIn(node, portfolio.nodes)
            self.assertTrue(report)
