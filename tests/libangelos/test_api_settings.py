#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
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
        try:
            value = str(123)
            self.facade.api.settings.set("Preferences", "Value", value)
            await self.facade.api.settings.save_preferences()
            await self.facade.api.settings.load_preferences()
            self.assertEqual(self.facade.api.settings.get("Preferences", "Value"), value)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_save_preferences(self):
        try:
            value = str(123)
            self.facade.api.settings.set("Preferences", "Value", value)
            await self.facade.api.settings.save_preferences()
            await self.facade.api.settings.load_preferences()
            self.assertEqual(self.facade.api.settings.get("Preferences", "Value"), value)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_load_set(self):
        data = {
            ("Foo", 1),
            ("Bar", 2),
            ("Baz", 3)
        }
        try:
            await self.facade.api.settings.save_set("variables.csv", data)
            self.assertEqual(await self.facade.api.settings.load_set("variables.csv"), data)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_save_set(self):
        data = {
            ("Foo", 1),
            ("Bar", 2),
            ("Baz", 3)
        }
        try:
            await self.facade.api.settings.save_set("variables.csv", data)
            self.assertEqual(await self.facade.api.settings.load_set("variables.csv"), data)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_networks(self):
        data = {
            (str(uuid.uuid4()), True),
            (str(uuid.uuid4()), False),
            (str(uuid.uuid4()), False)
        }
        try:
            await self.facade.api.settings.save_set("networks.csv", data)
            self.assertEqual(await self.facade.api.settings.networks(), data)
        except Exception as e:
            self.fail(e)
