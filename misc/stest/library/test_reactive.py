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
import tracemalloc
from unittest import TestCase

from libangelos.reactive import Event, NotifierMixin, ObserverMixin

from tests.support.generate import run_async


class StubNotifier(NotifierMixin):
    """Stub notifier."""
    pass


class StubObserver(ObserverMixin):
    """Stub observer."""
    event = None

    async def notify(self, event: Event):
        self.event = event


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
        await self.notifier.notify_all(10, {"hello": "world"})
        self.assertIs(self.observer.event.sender, self.notifier)

    @run_async
    async def test_action(self):
        await self.notifier.notify_all(10, {"hello": "world"})
        self.assertIs(self.observer.event.action, 10)

    @run_async
    async def test_data(self):
        await self.notifier.notify_all(10, {"hello": "world"})
        self.assertIs(self.observer.event.data["hello"], "world")


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
        self.notifier.subscribe(self.observer)

    def test_unsubscribe(self):
        self.notifier.subscribe(self.observer)
        self.notifier.unsubscribe(self.observer)

    @run_async
    async def test_notify_all(self):
        self.notifier.subscribe(self.observer)
        await self.notifier.notify_all(10, {"hello": "world"})
        self.assertIs(self.observer.event.data["hello"], "world")


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
        self.observer.add_subscription(self.notifier)

    def test_end_subscription(self):
        self.observer.add_subscription(self.notifier)
        self.observer.end_subscription(self.notifier)

    @run_async
    async def test_notify(self):
        await self.observer.notify(Event(self.notifier, 10, {"hello": "world"}))
        self.assertIsInstance(self.observer.event, Event)
