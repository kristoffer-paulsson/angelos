# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Layout for new Facade framework."""
import time
import datetime
import math
import logging
import asyncio
from libangelos.facade.base import BaseFacade, FacadeExtension
from libangelos.reactive import NotifierMixin


class TaskFacadeExtension(FacadeExtension, NotifierMixin):
    """Task extension that runs as a background job in the facade."""

    INVOKABLE = (False,)
    SCHEDULABLE = (False,)
    PERIODIC = (False,)

    ACTION_START = 1
    ACTION_COMPLETE = 2
    ACTION_CRASH = 3
    ACTION_PROGRESS = 4

    def __init__(self, facade: BaseFacade, loop: asyncio.AbstractEventLoop = None):
        """Initialize the task."""
        FacadeExtension.__init__(self, facade)
        NotifierMixin.__init__(self)

        self.__loop = loop if loop else asyncio.get_event_loop()
        self.__running = False
        self.__task = None
        self.__handle = None
        self.__period = None
        self.__period_start = None
        self.__timer = None
        self.__time_start = None
        self.__time_end = None

    @property
    def running(self):
        """Property exposing running state."""
        return self.__running

    def invoke(self) -> bool:
        """Invoke the task directly.

        Returns True if invocation went through. If invoking isn't available returns False."""
        if self.INVOKABLE[0]:
            self.__handle = self.__loop.call_soon(self.__launch)
            return True
        return False

    def schedule(self, when: datetime.datetime) -> bool:
        """Schedule a one-time execution of the task.

        Tell when you want the task to be executed. Returns false if task scheduling isn't available."""
        if self.SCHEDULABLE[0]:
            delay = (when - datetime.datetime.now()).total_seconds()
            self.__timer = self.__loop.call_later(delay, self.__launch)
            return True
        return False

    def periodic(self, period: datetime.timedelta, origin: datetime.datetime = datetime.datetime.now()) -> bool:
        """Execute task periodically until canceled.

        Tell the period between executions and from when to count the start. Returns false if periodic execution isn't
        available."""
        if self.PERIODIC[0]:
            self.__period = period.total_seconds()
            self.__period_start = origin.timestamp()
            self.__next_run()
            return True
        return False

    def cancel(self) -> None:
        """Cancel a scheduled or periodic pending execution."""
        if self.__handle:
            self.__handle.cancel()

        self.__period = None
        self.__period_start = None

    def __next_run(self) -> None:
        """Prepare and set next periodical execution."""
        moment = datetime.datetime.now().timestamp()
        uptime = moment - self.__period_start
        cycles = uptime / self.__period
        full_cycle = math.ceil(cycles) * self.__period
        run_in = full_cycle - uptime
        when = self.__loop.time() + run_in
        self.__timer = self.__loop.call_at(when, self.__launch)

    def __start(self) -> bool:
        """Standard preparations before execution."""
        self.__time_end = 0
        self.__running = True
        self.notify_all(self.ACTION_START, {"name": self.ATTRIBUTE[0]})
        self.__time_start = time.monotonic_ns()
        return True

    def __end(self) -> None:
        """Standard cleanup after execution."""
        self.__time_end = time.monotonic_ns()
        self.notify_all(self.ACTION_COMPLETE, {"name": self.ATTRIBUTE[0]})
        self.__running = False
        if self.__period:
            self.__next_run()

    def _progress(self, progress: float=0):
        """Notify observers made progress."""
        self.notify_all(self.ACTION_PROGRESS, {"name": self.ATTRIBUTE[0], "progress": progress})

    async def _run(self) -> None:
        """Actual task logic to be implemented here."""
        raise NotImplementedError()

    async def _initialize(self) -> None:
        """Custom initialization before task execution."""
        pass

    async def _finalize(self) -> None:
        """Custom cleanup after task execution."""
        pass

    def __launch(self) -> bool:
        """Task launcher and exception logic."""
        if self.__running:
            return False

        self.__task = self.__loop.create_task(self.__exe())
        self.__task.add_done_callback(self.__done)

    def __done(self, task):
        exc = task.exception()
        if exc:
            logging.error(exc, exc_info=True)
            self.notify_all(self.ACTION_CRASH, {
                "name": self.ATTRIBUTE[0], "task": self.__task, "exception": exc})
        else:
            logging.info("Task \"%s\" finished execution" % self.ATTRIBUTE[0])

    async def __exe(self) -> None:
        """Task executor that prepares, executes and finalizes."""
        self.__start()
        await self._initialize()
        await self._run()
        await self._finalize()
        self.__end()
