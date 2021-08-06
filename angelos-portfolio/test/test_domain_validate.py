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
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.domain.validate import ValidateDomain
from angelos.portfolio.entity.create import CreatePersonEntity

from test.fixture.generate import Generate


class TestValidateDomain(TestCase):
    def test_validate(self):
        data = PersonData(**Generate.person_data()[0])
        portfolio = CreatePersonEntity().perform(data)
        ext_portfolio = copy.deepcopy(portfolio)
        domain = CreateDomain().perform(portfolio)

        self.assertIsNotNone(portfolio.domain)
        with evaluate("Domain:Validate") as report:
            ValidateDomain().validate(portfolio, domain)
            self.assertTrue(report)

        self.assertIsNone(ext_portfolio.domain)
        with evaluate("Domain:Validate") as report:
            ValidateDomain().validate(ext_portfolio, domain)
            self.assertTrue(report)

