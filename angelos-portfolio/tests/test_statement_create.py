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
from angelos.portfolio.statement.create import CreateTrustedStatement, CreateVerifiedStatement, CreateRevokedStatement


class TestCreateTrustedStatement(TestCase):
    def test_perform(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        with evaluate("Trusted:Create") as r:
            statement = CreateTrustedStatement().perform(issuer, owner)
            self.assertIn(statement, issuer.trusted_issuer)
            print(r.format())
            print(issuer)


class TestCreateVerifiedStatement(TestCase):
    def test_perform(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        with evaluate("Verified:Create") as r:
            statement = CreateVerifiedStatement().perform(issuer, owner)
            self.assertIn(statement, issuer.verified_issuer)
            print(r.format())
            print(issuer)


class TestCreateRevokedStatement(TestCase):
    def test_perform(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        statement = CreateVerifiedStatement().perform(issuer, owner)
        with evaluate("Trusted:Create") as r:
            revoked = CreateRevokedStatement().perform(issuer, statement)
            self.assertIn(revoked, issuer.revoked_issuer)
            print(r.format())
            print(issuer)



