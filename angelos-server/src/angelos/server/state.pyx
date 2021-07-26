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
"""State machine."""
import asyncio

from angelos.lib.error import AngelosException
from angelos.common.utils import Event


class StateMachineError(AngelosException):
    pass  # noqa E701


class StateMissconfiguredError(StateMachineError):
    pass  # noqa E701


class StateBlockedError(StateMachineError):
    pass  # noqa E701


class StateDependencyError(StateMachineError):
    pass  # noqa E701


class State:
    name = None
    """Unique name of the state in the statemachine."""

    blocking = []
    """Blocking states that must be OFF for this state to turn ON."""

    depends = []
    """Dependencies that must be ON for this state to turn ON."""

    switches = []
    """Switch the following states OFF when this turns ON."""

    def __init__(self, name=None, blocking=[], depends=[], switches=[]):
        """Init the state"""
        if not (self.name or name):
            raise StateMissconfiguredError("State name not set")
        elif self.name and name:
            raise StateMissconfiguredError("State name can not be set twice")
        elif name and not self.name:
            self.name = name

        if self.blocking and blocking:
            raise StateMissconfiguredError(
                "State blockers can not be set twice"
            )
        else:
            self.blocking = blocking

        if self.depends and depends:
            raise StateMissconfiguredError(
                "State dependencies can not be set twice"
            )
        else:
            self.depends = depends

        if self.switches and switches:
            raise StateMissconfiguredError("State name can not be set twice")
        elif switches and not self.switches:
            self.switches = switches

        self.__state = False
        self.__on = Event()
        self.__off = Event()

    @property
    def state(self):
        return self.__state

    def switch(self, turn=None):
        """Flip the current state and clear and set the ON/OFF events."""
        if turn is None:
            self.__state = not self.__state
        else:
            self.__state = bool(turn)

        if self.__state:
            self.__off.clear()
            self.__on.set()
        else:
            self.__on.clear()
            self.__off.set()

        return self.__state

    async def wait(self, turn=None):
        """wait for the opposite event of current state to happen."""
        if turn is None:
            if self.__state:
                return await self.__off.wait()
            else:
                return await self.__on.wait()
        elif turn is True:
            return await self.__on.wait()
        elif turn is False:
            return await self.__off.wait()
        else:
            return


class StateMachine:
    def __init__(self, states=[]):
        self.__states = {}
        self.__lock = asyncio.Lock
        self.__counter = 0

        for args in states:
            si = State(**args)
            self.__states[si.name] = si

    @property
    def states(self):
        return self.__states.keys()

    def position(self, state):
        return self.__get(state).state

    def __call__(self, state, turn=None):
        if state == "all" and turn is False:
            for name in self.__states.keys():
                self.__do_turn(self.__get(name), False)
            return True
        return self.__do_turn(self.__get(state), turn)

    """def __enter__(self):
        self.__lock.acquire()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.__lock.release()
        raise exc_type(exc_val)
        """

    def __get(self, state):
        if state not in self.__states:
            raise StateMissconfiguredError(
                'There is no state "%s" configured' % state
            )
        return self.__states[state]

    def __do_turn(self, si, turn):
        if turn is True:
            self.__validate(si)

        for switch in si.switches:
            self.__do_turn(self.__get(switch), False)

        return si.switch(turn)

    def __validate(self, si):
        blocking = []
        for name in si.blocking:
            b = self.__get(name)
            if b.state:
                blocking.append(b.name)
        if len(blocking):
            raise StateBlockedError(
                'State "%s" blocked by: "%s"'
                % (si.name, '", "'.join(blocking))
            )

        missing = []
        for name in si.depends:
            d = self.__get(name)
            if not d.state:
                missing.append(d.name)
        if len(missing):
            raise StateDependencyError(
                'Dependencies "%s" not fullfiled for state "%s"'
                % ('", "'.join(missing), si.name)
            )

    async def on(self, state):
        await self.__get(state).wait(True)
        return self

    async def off(self, state):
        await self.__get(state).wait(False)
        return self
