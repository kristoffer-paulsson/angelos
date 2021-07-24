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
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio
from angelos.portfolio.statement.accept import AcceptTrustedStatement, AcceptVerifiedStatement, \
    AcceptRevokedStatement
from angelos.portfolio.statement.create import CreateTrustedStatement, CreateVerifiedStatement, CreateRevokedStatement


class TestAcceptTrustedStatement(TestCase):
    def test_validate(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        foreign_issuer = issuer.to_portfolio()
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateTrustedStatement().perform(issuer, owner)
        with evaluate("Trusted:Accept") as report:
            AcceptTrustedStatement().validate(foreign_issuer, statement)
            self.assertIn(statement, foreign_issuer.trusted_issuer)
        self.assertTrue(report)


class TestAcceptVerifiedStatement(TestCase):
    def test_validate(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        foreign_issuer = issuer.to_portfolio()
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateVerifiedStatement().perform(issuer, owner)
        with evaluate("Verified:Accept") as report:
            AcceptVerifiedStatement().validate(foreign_issuer, statement)
            self.assertIn(statement, foreign_issuer.verified_issuer)
        self.assertTrue(report)


class TestAcceptRevokedStatement(TestCase):
    def test_validate(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        foreign_issuer = issuer.to_portfolio()
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateVerifiedStatement().perform(issuer, owner)
        revoked = CreateRevokedStatement().perform(issuer, statement)
        with evaluate("Revoked:Accept") as report:
            AcceptRevokedStatement().validate(foreign_issuer, revoked)
            self.assertIn(revoked, foreign_issuer.revoked_issuer)
        self.assertTrue(report)



