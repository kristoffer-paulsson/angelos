import asyncio
import tracemalloc
from unittest import TestCase

from libangelos.misc import Misc
from libangelos.reactive import Event, NotifierMixin, ObserverMixin


class Notifier(NotifierMixin):
    pass


class Observer(ObserverMixin):
    event = None

    async def notify(self, event: Event):
        self.event = event


class TestEvent(TestCase):
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

    def test_sender(self):
        try:
            asyncio.run(self.notifier.notify_all(10, {"hello": "world"}))
            self.assertIs(self.observer.event.sender, self.notifier)
        except Exception as e:
            self.fail()

    def test_action(self):
        try:
            asyncio.run(self.notifier.notify_all(10, {"hello": "world"}))
            self.assertIs(self.observer.event.action, 10)
        except Exception as e:
            self.fail()

    def test_data(self):
        try:
            asyncio.run(self.notifier.notify_all(10, {"hello": "world"}))
            self.assertIs(self.observer.event.data["hello"], "world")
        except Exception as e:
            self.fail()
