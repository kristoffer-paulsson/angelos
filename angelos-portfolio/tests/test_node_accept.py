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
import copy
from unittest import TestCase

from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData
from angelos.meta.fake import Generate
from angelos.portfolio.node.accept import AcceptUpdatedNode
from angelos.portfolio.node.update import UpdateNode
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio


class TestAcceptUpdatedEntity(TestCase):
    def test_validate(self):
        portfolio = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        ext_portfolio = copy.deepcopy(portfolio)
        node = UpdateNode().perform(ext_portfolio, set(ext_portfolio.nodes).pop())
        with evaluate("Node:AcceptUpdate") as r:
            AcceptUpdatedNode().validate(portfolio, node)
            print(portfolio)
            print(r.format())