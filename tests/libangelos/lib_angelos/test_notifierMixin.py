import asyncio
import tracemalloc
from unittest import TestCase

from libangelos.reactive import Event, NotifierMixin, ObserverMixin


class Notifier(NotifierMixin):
    pass


class Observer(ObserverMixin):
    event = None

    async def notify(self, event: Event):
        self.event = event


class TestNotifierMixin(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.observer = Observer()
        self.notifier = Notifier()

    def tearDown(self) -> None:
        del self.observer
        del self.notifier

    def test_subscribe(self):
        try:
            self.notifier.subscribe(self.observer)
        except Exception as e:
            self.fail()

    def test_unsubscribe(self):
        try:
            self.notifier.subscribe(self.observer)
            self.notifier.unsubscribe(self.observer)
        except Exception as e:
            self.fail()

    def test_notify_all(self):
        try:
            self.notifier.subscribe(self.observer)
            asyncio.run(self.notifier.notify_all(10, {"hello": "world"}))
            self.assertIs(self.observer.event.data["hello"], "world")
        except Exception as e:
            self.fail()
