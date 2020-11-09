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

import pyximport; pyximport.install()
from angelos.portfolio.entity.newkey import NewKeys
from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData
from angelos.meta.fake import Generate
from angelos.portfolio.entity.create import CreatePersonEntity

from unittest import TestCase


class TestNewKeys(TestCase):
    def test_perform(self):
        portfolio = CreatePersonEntity().perform(PersonData(**Generate.person_data()[0]))
        old_privkeys = copy.deepcopy(portfolio.privkeys)
        with evaluate("Keys:New") as report:
            _, privkeys = NewKeys().perform(portfolio)
        self.assertTrue(report)
        self.assertNotEqual(privkeys, old_privkeys)
