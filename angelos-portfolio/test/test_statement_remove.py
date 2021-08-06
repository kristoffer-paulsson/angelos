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
from angelos.portfolio.statement.accept import AcceptRevokedStatement, AcceptVerifiedStatement
from angelos.portfolio.statement.create import CreateVerifiedStatement, CreateRevokedStatement
from angelos.portfolio.statement.remove import RemoveRevokedStatement

from test.fixture.generate import Generate


class TestRemoveRevokedStatement(TestCase):
    def test_perform(self):
        issuer = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))
        owner = SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0]))

        foreign_issuer = issuer.to_portfolio()
        verified = CreateVerifiedStatement().perform(issuer, owner)
        AcceptVerifiedStatement().validate(foreign_issuer, verified)
        self.assertIn(verified, foreign_issuer.verified_issuer)

        revoked = CreateRevokedStatement().perform(issuer, verified)
        AcceptRevokedStatement().validate(foreign_issuer, revoked)
        self.assertIn(revoked, foreign_issuer.revoked_issuer)

        with evaluate("Revoked:Remove") as report:
            RemoveRevokedStatement().perform(foreign_issuer, revoked)
            self.assertIn(revoked, foreign_issuer.revoked_issuer)
            self.assertNotIn(verified, foreign_issuer.verified_issuer)
        self.assertTrue(report)