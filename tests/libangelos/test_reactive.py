#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import tracemalloc

from angelossim.stub import StubObserver, StubNotifier
from unittest import TestCase

from angelossim.support import run_async
from libangelos.reactive import Event


class TestEvent(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.observer = StubObserver()
        self.notifier = StubNotifier()
        self.notifier.subscribe(self.observer)

    def tearDown(self) -> None:
        del self.observer
        del self.notifier

    @run_async
    async def test_sender(self):
        try:
            await self.notifier.notify_all(10, {"hello": "world"})
            self.assertIs(self.observer.event.sender, self.notifier)
        except Exception as e:
            self.fail()

    @run_async
    async def test_action(self):
        try:
            await self.notifier.notify_all(10, {"hello": "world"})
            self.assertIs(self.observer.event.action, 10)
        except Exception as e:
            self.fail()

    @run_async
    async def test_data(self):
        try:
            await self.notifier.notify_all(10, {"hello": "world"})
            self.assertIs(self.observer.event.data["hello"], "world")
        except Exception as e:
            self.fail()


class TestNotifierMixin(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.observer = StubObserver()
        self.notifier = StubNotifier()

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

    @run_async
    async def test_notify_all(self):
        try:
            self.notifier.subscribe(self.observer)
            await self.notifier.notify_all(10, {"hello": "world"})
            self.assertIs(self.observer.event.data["hello"], "world")
        except Exception as e:
            self.fail()


class TestObserverMixin(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.observer = StubObserver()
        self.notifier = StubNotifier()
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

    @run_async
    async def test_notify(self):
        try:
            await self.observer.notify(Event(self.notifier, 10, {"hello": "world"}))
            self.assertIsInstance(self.observer.event, Event)
        except Exception as e:
            self.fail()
