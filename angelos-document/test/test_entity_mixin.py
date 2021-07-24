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

from angelos.document.document import Document, DocumentError
from angelos.document.entity_mixin import PersonMixin, MinistryMixin, ChurchMixin


class StubDocument(Document, PersonMixin):
    pass


class TestPersonMixin(TestCase):
    def setUp(self):
        self.instance = StubDocument(nd={
            "given_name": "John",
            "names": ["John", "Mark"]
        })

    def tearDown(self):
        del self.instance

    def test__check_names(self):
        PersonMixin._check_names(self.instance)

        with self.assertRaises(DocumentError) as context:
            self.instance.given_name = "Judah"
            PersonMixin._check_names(self.instance)

    def test_apply_rules(self):
        self.assertTrue(PersonMixin.apply_rules(self.instance))


class TestMinistryMixin(TestCase):
    def setUp(self):
        self.instance = MinistryMixin()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())



class TestChurchMixin(TestCase):
    def setUp(self):
        self.instance = ChurchMixin()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())