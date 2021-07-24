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

from angelos.document.messages import Attachment, Message, Note, Instant, Mail, Share, Report


class TestAttachment(TestCase):
    def setUp(self):
        self.instance = Attachment()

    def tearDown(self):
        del self.instance


class TestMessage(TestCase):
    def setUp(self):
        self.instance = Message()

    def tearDown(self):
        del self.instance


class TestNote(TestCase):
    def setUp(self):
        self.instance = Note()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestInstant(TestCase):
    def setUp(self):
        self.instance = Instant()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestMail(TestCase):
    def setUp(self):
        self.instance = Mail()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestShare(TestCase):
    def setUp(self):
        self.instance = Share()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())


class TestReport(TestCase):
    def setUp(self):
        self.instance = Report()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        self.assertTrue(self.instance.apply_rules())
