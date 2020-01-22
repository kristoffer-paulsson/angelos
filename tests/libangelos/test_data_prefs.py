from libangelos.misc import Misc

from dummy.stub import StubObserver
from dummy.support import run_async
from dummy.testing import BaseTestFacade


class TestPreferencesData(BaseTestFacade):
    """Test the facade.data.prefs instance on the facade, which is a DictionaryMixin."""

    @run_async
    async def test___getitem__(self):
        try:
            value = 1
            self.facade.data.prefs["Value"] = value
            self.assertEqual(value, self.facade.data.prefs["Value"])
        except Exception as e:
            self.fail(e)

    @run_async
    async def test___setitem__(self):
        try:
            value = 1
            self.facade.data.prefs["Value"] = value
            self.assertEqual(value, self.facade.data.prefs["Value"])
        except Exception as e:
            self.fail(e)

    @run_async
    async def test___delitem__(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_subscribe(self):
        self.observer = StubObserver()
        self.facade.data.prefs.subscribe("Value", self.observer)

        try:
            self.facade.data.prefs["Value"] = 123
            await Misc.sleep()
            self.assertEqual(self.observer.event.data["value"], 123)
        except Exception as e:
            self.fail(e)

        del self.observer

    @run_async
    async def test_unsubscribe(self):
        self.observer = StubObserver()
        self.facade.data.prefs.subscribe("Value", self.observer)

        try:
            self.facade.data.prefs.unsubscribe("Value", self.observer)
            self.facade.data.prefs["Value"] = 123
            await Misc.sleep()
            self.assertEqual(self.observer.event, None)
        except Exception as e:
            self.fail(e)

        del self.observer
