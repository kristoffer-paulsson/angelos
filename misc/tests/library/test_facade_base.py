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
import os
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.facade.base import BaseFacade

from libangelos.facade.facade import Facade
from tests.support.generate import run_async


class TestBaseFacade(TestCase):
    def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.instance = Facade(self.home, os.urandom(32))

    def tearDown(self) -> None:
        del self.instance
        self.dir.cleanup()

    @run_async
    async def test__post_init(self):
        with self.assertRaises(NotImplementedError):
            await self.instance._post_init()

    def test_path(self):
        self.assertEqual(self.instance.path, self.home)

    def test_secret(self):
        self.assertIs(type(self.instance.secret), bytes)
        self.assertIs(len(self.instance.secret), 32)

    def test_closed(self):
        self.assertFalse(self.instance.closed)
        self.instance.close()
        self.assertTrue(self.instance.closed)

    def test_data(self):
        self.assertIs(type(self.instance.data), dict)

    def test_api(self):
        self.assertIs(type(self.instance.api), dict)

    def test_task(self):
        self.assertIs(type(self.instance.task), dict)

    def test_archive(self):
        self.assertIs(type(self.instance.archive), dict)

    @run_async
    async def test_open(self):
        with self.assertRaises(NotImplementedError):
            await BaseFacade.open(self.home, self.instance.secret)

    def test_close(self):
        self.instance.close()
        self.assertTrue(self.instance.closed)
