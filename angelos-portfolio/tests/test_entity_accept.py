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
from angelos.portfolio.entity.accept import ValidateEntity
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio

from unittest import TestCase


class TestValidateEntity(TestCase):
    def test_validate(self):
        data = PersonData(**Generate.person_data()[0])
        portfolio = SetupPersonPortfolio().perform(data)
        with evaluate("Entity:Validate") as r:
            ValidateEntity().validate(portfolio)
            print(r.format())
            print(portfolio)