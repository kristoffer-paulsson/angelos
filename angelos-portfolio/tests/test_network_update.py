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
from angelos.portfolio.network.update import UpdateNetwork
from angelos.portfolio.portfolio.setup import SetupChurchPortfolio, ChurchData


class TestUpdateDomain(TestCase):
    def test_perform(self):
        portfolio = SetupChurchPortfolio().perform(ChurchData(**Generate.church_data()[0]), server=True)
        with evaluate("Network:Update") as r:
            network = UpdateNetwork().perform(portfolio)
            self.assertEqual(network, portfolio.network)
            print(portfolio)
            print(r.format())