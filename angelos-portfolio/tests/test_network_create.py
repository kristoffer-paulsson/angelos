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
import pyximport; pyximport.install()
from angelos.portfolio.node.create import CreateNode
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.network.create import CreateNetwork
from angelos.common.policy import evaluate
from angelos.lib.policy.types import ChurchData
from angelos.meta.fake import Generate
from angelos.portfolio.entity.create import CreateChurchEntity

from unittest import TestCase


class TestCreateNetwork(TestCase):
    def test_perform(self):
        data = ChurchData(**Generate.church_data()[0])
        portfolio = CreateChurchEntity().perform(data)
        CreateDomain().perform(portfolio)
        CreateNode().current(portfolio, server=True)
        with evaluate("Network:Create") as r:
            CreateNetwork().perform(portfolio)
            print(r.format())
            print(portfolio)
