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
from libangelos.misc import Misc

from angelossim.stub import StubObserver
from angelossim.support import run_async
from angelossim.testing import BaseTestFacade


class TestPreferencesData(BaseTestFacade):
    """Test the facade.data.prefs instance on the facade, which is a DictionaryMixin."""
    count = 1

    @run_async
    async def test___getitem__(self):
        value = 1
        self.facade.data.prefs["Value"] = value
        self.assertEqual(value, self.facade.data.prefs["Value"])

    @run_async
    async def test___setitem__(self):
        value = 1
        self.facade.data.prefs["Value"] = value
        self.assertEqual(value, self.facade.data.prefs["Value"])

    @run_async
    async def test___delitem__(self):
        self.fail(e)

    @run_async
    async def test_subscribe(self):
        self.observer = StubObserver()
        self.facade.data.prefs.subscribe("Value", self.observer)

        self.facade.data.prefs["Value"] = 123
        await Misc.sleep()
        self.assertEqual(self.observer.event.data["value"], 123)

        del self.observer

    @run_async
    async def test_unsubscribe(self):
        self.observer = StubObserver()
        self.facade.data.prefs.subscribe("Value", self.observer)

        self.facade.data.prefs.unsubscribe("Value", self.observer)
        self.facade.data.prefs["Value"] = 123
        await Misc.sleep()
        self.assertEqual(self.observer.event, None)

        del self.observer


class TestClientData(BaseTestFacade):
    """Test the facade.data.client instance on the facade, which is a DictionaryMixin."""
    count = 1

    @run_async
    async def test___getitem__(self):
        value = 1
        self.facade.data.client["Value"] = value
        self.assertEqual(value, self.facade.data.client["Value"])

    @run_async
    async def test___setitem__(self):
        value = 1
        self.facade.data.client["Value"] = value
        self.assertEqual(value, self.facade.data.client["Value"])

    @run_async
    async def test___delitem__(self):
        self.fail(e)

    @run_async
    async def test_subscribe(self):
        self.observer = StubObserver()
        self.facade.data.client.subscribe("Value", self.observer)

        self.facade.data.client["Value"] = 123
        await Misc.sleep()
        self.assertEqual(self.observer.event.data["value"], 123)

        del self.observer

    @run_async
    async def test_unsubscribe(self):
        self.observer = StubObserver()
        self.facade.data.client.subscribe("Value", self.observer)

        self.facade.data.client.unsubscribe("Value", self.observer)
        self.facade.data.client["Value"] = 123
        await Misc.sleep()
        self.assertEqual(self.observer.event, None)

        del self.observer