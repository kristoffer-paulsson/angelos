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
from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.meta.fake import Generate
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio, SetupMinistryPortfolio, SetupChurchPortfolio

from unittest import TestCase


class TestSetupPersonPortfolio(TestCase):
    def test_perform(self):
        data = PersonData(**Generate.person_data()[0])
        with evaluate("Person:Setup") as report:
            portfolio = SetupPersonPortfolio().perform(data)
        self.assertTrue(report)


class TestSetupMinistryPortfolio(TestCase):
    def test_perform(self):
        data = MinistryData(**Generate.ministry_data()[0])
        with evaluate("Ministry:Setup") as report:
            portfolio = SetupMinistryPortfolio().perform(data)
        self.assertTrue(report)


class TestSetupChurchPortfolio(TestCase):
    def test_perform(self):
        data = ChurchData(**Generate.church_data()[0])
        with evaluate("Church:Setup") as report:
            portfolio = SetupChurchPortfolio().perform(data, server=True)
        self.assertTrue(report)
