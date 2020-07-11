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

from libangelos.api.mailbox import DOCUMENT_PATH
from libangelos.document.document import DocType
from libangelos.misc import Misc


class TestMisc(TestCase):
    def test_unique(self):
        self.fail()

    def test_get_loop(self):
        self.fail()

    def test_urlparse(self):
        self.fail()

    def test_urlunparse(self):
        self.fail()

    def test_sleep(self):
        self.fail()

    def test_to_ini(self):
        try:
            self.assertEqual(Misc.to_ini(True), "true")
            self.assertEqual(Misc.to_ini(123), "123")
            self.assertEqual(Misc.to_ini(.123), "0.123")
            self.assertEqual(Misc.to_ini(None), "none")
            self.assertEqual(Misc.to_ini("Hello, world!"), "Hello, world!")
        except Exception as e:
            self.fail(e)

    def test_from_ini(self):
        try:
            self.assertEqual(Misc.from_ini("true"), True)
            self.assertEqual(Misc.from_ini("123"), 123)
            self.assertEqual(Misc.from_ini("0.123"), .123)
            self.assertEqual(Misc.from_ini("none"), None)
            self.assertEqual(Misc.from_ini("Hello, world!"), "Hello, world!")
        except Exception as e:
            self.fail(e)