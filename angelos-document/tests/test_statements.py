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
from unittest import TestCase

from angelos.document.statements import Statement, Verified, Trusted, Revoked


class TestStatement(TestCase):
    def setUp(self):
        self.instance = Statement()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestVerified(TestCase):
    def setUp(self):
        self.instance = Verified()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestTrusted(TestCase):
    def setUp(self):
        self.instance = Trusted()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestRevoked(TestCase):
    def setUp(self):
        self.instance = Revoked()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())