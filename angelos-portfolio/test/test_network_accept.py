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
from angelos.lib.policy.types import ChurchData
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.entity.create import CreateChurchEntity
from angelos.portfolio.network.accept import AcceptUpdatedNetwork, AcceptNetwork
from angelos.portfolio.network.create import CreateNetwork
from angelos.portfolio.network.update import UpdateNetwork
from angelos.portfolio.node.create import CreateNode
from angelos.portfolio.portfolio.setup import IPv4Address

from test.fixture.generate import Generate


class TestAcceptNetwork(TestCase):
    def test_validate(self):
        portfolio = CreateChurchEntity().perform(ChurchData(**Generate.church_data()[0]))
        CreateDomain().perform(portfolio)
        CreateNode().current(portfolio, server=True)

        foreign_porfolio = portfolio.to_portfolio()
        self.assertIsNone(foreign_porfolio.network)
        network = CreateNetwork().perform(portfolio)

        with evaluate("Network:Accept") as report:
            AcceptNetwork().validate(foreign_porfolio, network)
            self.assertIs(network, foreign_porfolio.network)
        self.assertTrue(report)


class TestAcceptUpdatedNetwork(TestCase):
    def test_validate(self):
        portfolio = CreateChurchEntity().perform(ChurchData(**Generate.church_data()[0]))
        CreateDomain().perform(portfolio)
        CreateNode().current(portfolio, server=True)

        foreign_porfolio = portfolio.to_portfolio()
        self.assertIsNone(foreign_porfolio.network)
        network = CreateNetwork().perform(portfolio)
        AcceptNetwork().validate(foreign_porfolio, network)

        CreateNode().perform(portfolio, device="test", serial="1234567890", ip=IPv4Address("127.0.0.1"), server=True)
        network = UpdateNetwork().perform(portfolio)

        with evaluate("Network:AcceptUpdated") as report:
            AcceptUpdatedNetwork().validate(foreign_porfolio, network)
            self.assertIs(network, foreign_porfolio.network)
        self.assertTrue(report)