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
from angelos.portfolio.domain.update import UpdateDomain
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio

from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData
from angelos.meta.fake import Generate

from unittest import TestCase


class TestUpdateDomain(TestCase):
    def test_perform(self):
        portfolio = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        with evaluate("Domain:Update") as r:
            domain = UpdateDomain().perform(portfolio)
            self.assertEqual(domain, portfolio.domain)
            print(portfolio)
            print(r.format())