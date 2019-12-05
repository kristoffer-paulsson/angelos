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


class TestObserverMixin(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.observer = Observer()
        self.notifier = Notifier()
        self.notifier.subscribe(self.observer)

    def tearDown(self) -> None:
        del self.observer
        del self.notifier

    def test_add_subscription(self):
        try:
            self.observer.add_subscription(self.notifier)
        except Exception as e:
            self.fail()

    def test_end_subscription(self):
        try:
            self.observer.add_subscription(self.notifier)
            self.observer.end_subscription(self.notifier)
        except Exception as e:
            self.fail()

    def test_notify(self):
        try:
            asyncio.run(self.observer.notify(Event(self.notifier, 10, {"hello": "world"})))
            self.assertIsInstance(self.observer.event, Event)
        except Exception as e:
            self.fail()
