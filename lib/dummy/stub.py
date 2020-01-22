# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Stub classes for dummy and unit testing."""
from libangelos.reactive import Event
from libangelos.reactive import NotifierMixin, ObserverMixin


class StubNotifier(NotifierMixin):
    """Stub notifier."""
    pass


class StubObserver(ObserverMixin):
    """Stub observer."""
    event = None

    async def notify(self, event: Event):
        self.event = event
