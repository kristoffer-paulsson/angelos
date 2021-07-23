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
import uuid
from ipaddress import IPv4Address

from libangelos.data.dict_mixin import DictionaryMixin

from angelossim.support import run_async, Generate
from angelossim.testing import BaseTestFacade


class TestSettingsAPI(BaseTestFacade):
    count = 1

    @run_async
    async def test_load_preferences(self):
        value = str(123)
        self.facade.api.settings.set("Preferences", "Value", value)
        await self.facade.api.settings.save_preferences()
        await self.facade.api.settings.load_preferences()
        self.assertEqual(self.facade.api.settings.get("Preferences", "Value"), value)

    @run_async
    async def test_save_preferences(self):
        value = str(123)
        self.facade.api.settings.set("Preferences", "Value", value)
        await self.facade.api.settings.save_preferences()
        await self.facade.api.settings.load_preferences()
        self.assertEqual(self.facade.api.settings.get("Preferences", "Value"), value)

    @run_async
    async def test_load_set(self):
        data = {
            ("Foo", 1),
            ("Bar", 2),
            ("Baz", 3)
        }
        await self.facade.api.settings.save_set("variables.csv", data)
        self.assertEqual(await self.facade.api.settings.load_set("variables.csv"), data)

    @run_async
    async def test_save_set(self):
        data = {
            ("Foo", 1),
            ("Bar", 2),
            ("Baz", 3)
        }
        await self.facade.api.settings.save_set("variables.csv", data)
        self.assertEqual(await self.facade.api.settings.load_set("variables.csv"), data)

    @run_async
    async def test_networks(self):
        data = {
            (str(uuid.uuid4()), True),
            (str(uuid.uuid4()), False),
            (str(uuid.uuid4()), False)
        }
        await self.facade.api.settings.save_set("networks.csv", data)
        self.assertEqual(await self.facade.api.settings.networks(), data)
