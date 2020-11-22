# cython: language_level=3
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
# TODO: Make unittest for all

import asyncio
from contextlib import ContextDecorator, AbstractContextManager
from contextvars import ContextVar
from typing import Callable, NamedTuple, NoReturn

from angelos.common.misc import Loop

observe_ctx = ContextVar("observe", default=None)

METHOD_NOTIFIERS = dict()


class NotifyEvent(NamedTuple):
    """Notification event."""

    notifier: Notifier
    action: int
    data: dict


class Observer:
    """Observing a notifier."""

    def __init__(self, dispatcher: Callable[[NotifyEvent], NoReturn], notifier: Notifier = None):
        self.__notifier = notifier
        self.__callback = dispatcher
        self.__notifier.observe(self)

    @property
    def stale(self) -> bool:
        """Whether observer is stale."""
        return bool(self.__notifier)

    async def notify(self, event: NotifyEvent):
        """Handle event from notifier."""
        if event.notifier != self.__notifier:
            raise ValueError("Illegal notifier.")
        if event.action == event.notifier.ACTION_DISREGARD:
            self.__notifier = None
        Loop.main().run(self.__callback(event))

    def __del__(self):
        if self.__notifier:
            self.__notifier.disregard(self)


class Notifier:
    """Notifies observers."""

    ACTION_DISREGARD = 0x80
    ACTION_BEGIN = 0x81
    ACTION_END = 0x82
    ACTION_SET = 0x83

    def __init__(self):
        self.__observers = set()

    async def notify_all(self, action: int, data: dict=None):
        """Notify all observers."""
        event = NotifyEvent(self, action, data)
        await asyncio.gather([observer.notify(event) for observer in self.__observers])

    def observe(self, observer: Observer):
        """Add observer to notifier."""
        if observer not in self.__observers:
            self.__observers.add(observer)

    def disregard(self, observer: Observer):
        """Release observer from notifier."""
        if observer in self.__observers:
            self.__observers.remove(observer)

    def __del__(self):
        Loop.main().run(self.notify_all(Notifier.ACTION_DISREGARD), wait=True)
        self.__observers = None


class ObservableAttribute:
    """Observable attribute on """

    def __init__(self):
        self.__attr = None
        self.__name = None

    def __set_name__(self, owner, name):
        if not isinstance(owner, Notifier):
            raise TypeError("Observable attributes can only be used in notifier sublcasses.")
        self.__name = name
        self.__attr = "_" + name

    def __get__(self, instance, owner):
        return getattr(instance, self.__attr)

    def __set__(self, instance, value):
        setattr(instance, self.__attr, value)
        instance.notify_all(Notifier.ACTION_SET, {
            "attribute": self.__name,
            "instance": instance,
            "value": value
        })


def notify(begin: int = Notifier.ACTION_BEGIN, end: int = Notifier.ACTION_END):
    """Decorate class method in order to notify observer.

    Specify the begin and end action with integers.
    """
    def decorator(func):
        """Create or load notifier for method."""
        if not func in METHOD_NOTIFIERS:
            METHOD_NOTIFIERS[func] = Notifier()
        notifier = METHOD_NOTIFIERS[func]

        def wrapper(self, *args, **kwargs):
            """Add observer to notifier.

            Notifier and Observer will be associated with each other and,
            function called notifying observers at begin and end.
            """
            observer = observe_ctx.get()
            if observer:
                observer.notifier = notifier

            notifier.notify_all(begin, {
                "callback": "{0}.{1}".format(self.__name__, func.__name__),
                "instance": self
            })
            result = func(self, *args, **kwargs)
            notifier.notify_all(end, {
                "callback": "{0}.{1}".format(self.__name__, func.__name__),
                "instance": self,
                "return": result
            })

            return result
        return wrapper
    return decorator


# Should be if not for 3.6 backward compatibility.
# AbstractAsyncContextManager
class observe(ContextDecorator, AbstractContextManager):
    """Observe methods and properties.

    Use as a context manager in order to observe all notifiable events inside a notifiable method or property. Keep
        returned observer for long term observation.
    Use as a decorator in order to receive all notifiable events inside a method.
    """

    def __init__(self, callback: Callable[[NotifyEvent], NoReturn]):
        self.__token = observe_ctx.set(Observer(callback))

    def __enter__(self) -> Observer:
        return observe_ctx.get()

    async def __aenter__(self) -> Observer:
        return observe_ctx.get()

    def __exit__(self, exc_type, exc_value, traceback) -> None:
        if exc_type is not None:
            raise exc_type(exc_value)

        observer = observe_ctx.get()
        observe_ctx.reset(self.__token)
        return None

    async def __aexit__(self, exc_type, exc_value, traceback) -> None:
        if exc_type is not None:
            raise exc_type(exc_value)

        observer = observe_ctx.get()
        observe_ctx.reset(self.__token)
        return None
