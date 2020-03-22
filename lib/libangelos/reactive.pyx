# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module for reactive programming, using the observer pattern."""
import asyncio
from typing import Set, Any


class Event:
    """Event used to notify the observer.

    Parameters
    ----------
    sender : NotifierMixin
        The notifier instance.
    action : int
        Action taken by the notifier.
    data : dict
        Data related to the action.

    Attributes
    ----------
    sender : NotifierMixin
        The sender instance.
    action : int
        Recent action to notify.
    data : dict
        Data related to the action.

    """
    def __init__(
        self, sender: "NotifierMixin", action: int=0, data: dict=None  # noqa F821
    ):
        self.__sender = sender
        self.__action = action
        self.__data = data

    @property
    def sender(self) -> "NotifierMixin":  # noqa F821
        """Sender property.

        Returns
        -------
        NotifierMixin
            The sender instance.

        """
        return self.__sender

    @property
    def action(self) -> int:
        """Action.

        Returns
        -------
        int
            Recent action to notify.

        """
        return self.__action

    @property
    def data(self) -> dict:
        """Data

        Returns
        -------
        dict
            Related data.

        """
        return self.__data


class ObserverMixin:
    """Mixin used to implement the observer patterh.

    The observer will be notified fron notifiers to whom it subscribes.

    Attributes
    ----------
    __subscriptions : Set[NotifierMixin]
        All notifiers subscribed to.

    """

    def __init__(self):
        self.__subscriptions  = set()

    def add_subscription(
        self, notifier: "NotifierMixin", internal: bool=False  # noqa F821
    ) -> None:
        """Add a subscription to the observer.

        Parameters
        ----------
        notifier : NotifierMixin
            Description of parameter `notifier`.
        internal : bool
            Internal use only.

        """
        self.__subscriptions.add(notifier)
        if not internal:
            notifier.subscribe(self, True)

    def end_subscription(
        self, notifier: "NotifierMixin", internal: bool=False  # noqa F821
    ) -> None:
        """End subscription from notifier.

        Parameters
        ----------
        notifier : NotifierMixin
            Notifier to end subscription.
        internal : bool
            Internal use only`.

        """
        self.__subscriptions.discard(notifier)
        if not internal:
            notifier.unsubscribe(self, True)

    async def notify(self, event: Event) -> None:
        """Invoked by the notifier.

        This method should be implemented on the observer class.

        Parameters
        ----------
        event : Event
            The nofitication itself.

        """
        raise NotImplementedError()

    def __del__(self):
        """Cancel all subscriptions upon deletion."""
        for observer in self.__subscriptions:
            observer.unsubscribe(self, True)
        self.__subscriptions.clear()


class NotifierMixin:
    """Mixin to implement the notifier pattern.

    Attributes
    ----------
    __subscribers : Set[ObserverMixin]
        All subscribers that observe.

    """

    def __init__(self):
        self.__subscribers = set()

    def subscribe(self, observer: "ObserverMixin", internal: bool=False) -> None:
        """Adds a subscriber to the notifier to be notified.

        Parameters
        ----------
        observer : ObserverMixin
            The subscriber class.
        internal : bool
            Internal use only.

        """
        self.__subscribers.add(observer)
        if not internal:
            observer.add_subscription(self, True)

    def unsubscribe(self, observer: "ObserverMixin", internal: bool=False) -> None:
        """Removes subscriber from the notifier

        Parameters
        ----------
        observer : ObserverMixin
            Observer to be removed.
        internal : bool
            Internal use only.

        """
        self.__subscribers.discard(observer)
        if not internal:
            observer.end_subscription(self, True)

    def notify_all(self, action: int, data: dict=None) -> asyncio.Task:
        """Invoke this method to notify all observers about an action.

        This method

        Parameters
        ----------
        action : int
            Integer representation of the action.
        data : dict
            Data associated with the action.

        Returns
        -------
        asyncio.Task
            Returns a task that gather all the notify() coroutines.

        """
        event = Event(self, action, data)
        return asyncio.ensure_future(asyncio.gather(*[obs.notify(event) for obs in self.__subscribers]))

    def __del__(self):
        """Cancel all subscriptions upon deletion."""
        for observer in self.__subscribers:
            observer.end_subscription(self, True)
        self.__subscribers.clear()


class ReactiveAttribute(NotifierMixin):
    """
    A class holding a value that can be subscribed to.
    """
    def __init__(self, attribute: str, value: Any=None):
        NotifierMixin.__init__(self)
        self.__attr = attribute
        self.__value = value

    def __get__(self, instance, owner):
        self.notify_all(1, {"attr": self.__attr, "value": self.__value})
        return self.__value

    def __set__(self, instance, value):
        self.__value = value
        self.notify_all(2, {"attr": self.__attr, "value": self.__value})

    def __delete__(self, instance):
        self.notify_all(3, {"attr": self.__attr, "value": self.__value})