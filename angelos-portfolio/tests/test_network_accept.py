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
from angelos.meta.fake import Generate
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.network.accept import ValidateNetwork, AcceptUpdatedNetwork
from angelos.portfolio.network.update import UpdateNetwork
from angelos.portfolio.portfolio.setup import SetupChurchPortfolio


def new_data(first: dict, second: dict, changeables: tuple):
    """Populate new data with old not changeable data."""
    for name, field in first.items():
        if name not in changeables:
            second[name] = field


class TestValidateNetwork(TestCase):
    def test_validate(self):
        private = SetupChurchPortfolio().perform(ChurchData(**Generate.church_data()[0]), server=True)
        portfolio = Portfolio(private.filter({private.network}))
        network = UpdateNetwork().perform(private)
        with evaluate("Network:Validate") as r:
            ValidateNetwork().validate(portfolio, network)
            print(r.format())
            print(portfolio)


class TestAcceptUpdatedEntity(TestCase):
    def test_validate(self):
        private = SetupChurchPortfolio().perform(ChurchData(**Generate.church_data()[0]), server=True)
        portfolio = Portfolio(private.documents())
        network = UpdateNetwork().perform(private)
        with evaluate("Person:AcceptUpdate") as r:
            portfolio = AcceptUpdatedNetwork().validate(portfolio, network)
            print(portfolio)
            print(r.format())