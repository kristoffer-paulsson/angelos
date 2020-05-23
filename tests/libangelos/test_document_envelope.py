#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
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
