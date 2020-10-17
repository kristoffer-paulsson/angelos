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

from angelos.document.profiles import Address, Social, Profile, PersonProfile, MinistryProfile, ChurchProfile


class TestAddress(TestCase):
    def setUp(self):
        self.instance = Address()

    def tearDown(self):
        del self.instance


class TestSocial(TestCase):
    def setUp(self):
        self.instance = Social()

    def tearDown(self):
        del self.instance


class TestProfile(TestCase):
    def setUp(self):
        self.instance = Profile()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestPersonProfile(TestCase):
    def setUp(self):
        self.instance = PersonProfile()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestMinistryProfile(TestCase):
    def setUp(self):
        self.instance = MinistryProfile()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestChurchProfile(TestCase):
    def setUp(self):
        self.instance = ChurchProfile()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())