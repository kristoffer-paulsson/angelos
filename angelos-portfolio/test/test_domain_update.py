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
from angelos.portfolio.domain.create import CreateDomain
from angelos.portfolio.domain.update import UpdateDomain
from angelos.portfolio.entity.create import CreatePersonEntity

from test.fixture.generate import Generate


class TestUpdateDomain(TestCase):
    def test_perform(self):
        data = PersonData(**Generate.person_data()[0])
        portfolio = CreatePersonEntity().perform(data)
        CreateDomain().perform(portfolio)

        self.assertIsNotNone(portfolio.domain)
        with evaluate("Domain:Update") as report:
            domain = UpdateDomain().perform(portfolio)
            self.assertIs(domain, portfolio.domain)
            self.assertTrue(report)