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
from angelos.meta.fake import Generate
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.entity.create import CreateChurchEntity
from angelos.portfolio.network.create import CreateNetwork
from angelos.portfolio.network.update import UpdateNetwork
from angelos.portfolio.node.create import CreateNode, IPv4Address
from angelos.portfolio.portfolio.setup import ChurchData


class TestUpdateNetwork(TestCase):
    def test_perform(self):
        portfolio = CreateChurchEntity().perform(ChurchData(**Generate.church_data()[0]))
        domain = CreateDomain().perform(portfolio)
        CreateNode().current(portfolio, server=True)
        CreateNetwork().perform(portfolio)

        CreateNode().perform(portfolio, device="test", serial="1234567890", ip=IPv4Address("127.0.0.1"), server=True)
        with evaluate("Network:Update") as report:
            network = UpdateNetwork().perform(portfolio)
            self.assertIs(network, portfolio.network)
            self.assertEqual(network.domain, domain.id)
            self.assertEqual(len(network.hosts), 2)
        self.assertTrue(report)