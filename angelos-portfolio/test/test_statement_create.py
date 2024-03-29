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
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio
from angelos.portfolio.statement.create import CreateTrustedStatement, CreateVerifiedStatement, CreateRevokedStatement

from test.fixture.generate import Generate


class TestCreateTrustedStatement(TestCase):
    def test_perform(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        with evaluate("Trusted:Create") as report:
            trusted = CreateTrustedStatement().perform(issuer, owner)
            self.assertIn(trusted, issuer.trusted_issuer)
        self.assertTrue(report)


class TestCreateVerifiedStatement(TestCase):
    def test_perform(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        with evaluate("Verified:Create") as report:
            verified = CreateVerifiedStatement().perform(issuer, owner)
            self.assertIn(verified, issuer.verified_issuer)
        self.assertTrue(report)


class TestCreateRevokedStatement(TestCase):
    def test_perform(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateVerifiedStatement().perform(issuer, owner)
        self.assertIn(statement, issuer.verified_issuer)
        with evaluate("Trusted:Create") as report:
            revoked = CreateRevokedStatement().perform(issuer, statement)
            self.assertIn(revoked, issuer.revoked_issuer)
        self.assertTrue(report)



