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
import datetime
from unittest import TestCase

from libangelos.document.envelope import Header, Envelope
from libangelos.error import DocumentShortExpiry


class TestHeader(TestCase):
    def setUp(self):
        self.instance = Header()

    def tearDown(self):
        del self.instance


class TestEnvelope(TestCase):
    def setUp(self):
        self.instance = Envelope()

    def tearDown(self):
        del self.instance

    def test__check_expiry_period(self):
        try:
            stub = Envelope()
            stub._check_expiry_period()
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentShortExpiry) as context:
            stub = Envelope()
            stub.created = datetime.date.today() + datetime.timedelta(2)
            stub._check_expiry_period()

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)
