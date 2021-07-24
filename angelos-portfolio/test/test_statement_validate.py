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
from angelos.meta.fake import Generate
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio
from angelos.portfolio.statement.validate import ValidateTrustedStatement, ValidateVerifiedStatement, \
    ValidateRevokedStatement
from angelos.portfolio.statement.create import CreateTrustedStatement, CreateVerifiedStatement, CreateRevokedStatement


class TestValidateTrustedStatement(TestCase):
    def test_validate(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        foreign_issuer = issuer.to_portfolio()
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateTrustedStatement().perform(issuer, owner)
        with evaluate("Trusted:Validate") as report:
            ValidateTrustedStatement().validate(foreign_issuer, statement)
            self.assertNotIn(statement, foreign_issuer.trusted_issuer)
        self.assertTrue(report)


class TestValidateVerifiedStatement(TestCase):
    def test_validate(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        foreign_issuer = issuer.to_portfolio()
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateVerifiedStatement().perform(issuer, owner)
        with evaluate("Verified:Validate") as report:
            ValidateVerifiedStatement().validate(foreign_issuer, statement)
            self.assertNotIn(statement, foreign_issuer.verified_issuer)
        self.assertTrue(report)


class TestValidateRevokedStatement(TestCase):
    def test_validate(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        foreign_issuer = issuer.to_portfolio()
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateVerifiedStatement().perform(issuer, owner)
        revoked = CreateRevokedStatement().perform(issuer, statement)
        with evaluate("Revoked:Validate") as report:
            ValidateRevokedStatement().validate(foreign_issuer, revoked)
            self.assertNotIn(revoked, foreign_issuer.revoked_issuer)
        self.assertTrue(report)



