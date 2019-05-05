import asyncio

from ..utils import Event
from ..error import AngelosException


class StateMachineError(AngelosException): pass
class StateMissconfiguredError(StateMachineError): pass
class StateBlockedError(StateMachineError): pass
class StateDependencyError(StateMachineError): pass


class State:
    name = None
    """Unique name of the state in the statemachine."""

    blockers = None
    """Blocking states that must be OFF for this state to turn ON."""

    depends = None
    """Dependencies that must be ON for this state to turn ON."""

    switches = None
    """Switch the following states OFF when this turns ON."""

    def __init__(self, name=None, blockers=None, depends=None, switches=None):
        """Init the state"""
        if not (self.name or name):
            raise StateMissconfiguredError('State name not set')
        elif self.name and name:
            raise StateMissconfiguredError('State name can not be set twice')
        elif name and not self.name:
            self.name = name

        if self.blockers and blockers:
            raise StateMissconfiguredError('State blockers can not be set twice')
        else:
            self.blockers = blockers

        if self.depends and depends:
            raise StateMissconfiguredError('State dependencies can not be set twice')
        else:
            self.depends = depends

        if self.switches and switches:
            raise StateMissconfiguredError('State name can not be set twice')
        elif switches and not self.switches:
            self.switches = switches

        self.__state = False
        self.__on = Event()
        self.__off = Event()
        self.switch(False)

    @property
    def state(self):
        return self.__state

    def switch(self, turn=None):
        """Flip the current state and clear and set the ON/OFF events."""
        if turn != None:
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
        if turn == None:
            if self.__state:
                return await self.__off.wait()
            else:
                return await self.__on.wait()
        elif turn:
            return await self.__on.wait()
        elif not turn:
            return await self.__off.wait()
        else:
            return


class StateMachine:
    def __init__(self, states=[]):
        self.__states = {}
        self.__lock = asyncio.Lock
        self.__counter = 0
        for s in states:
            state = State(**s)
            self.__states[state.name] = state

    @property
    def states(self):
        return self.__states.keys()

    def __call__(self, state, turn=None):
        with self.__lock:
            return self.__do_turn(self.__get(state), turn)

    def __enter__(self):
        self.__lock.acquire()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.__lock.release()
        raise exc_type(exc_val)

    def __get(self, state):
        if state not in self.states:
            raise StateMissconfiguredError(
                'There is no state "%s" configured' % state)
        return self.__states[state]

    def __do_turn(self, state, turn):
        if turn == True:
            self.__validate(state)

        for switch in state.switches:
            self.__do_turn(self.__get(switch), False)

        return state.switch(turn)

    def __validate(self, state):

        blockers = []
        for name in state.blockers:
            b = self.__get(name)
            if b.state:
                blockers.append(b)
        if blockers:
            raise StateBlockedError('State "%s" blocked by: "%s"' % (
                state.name, '", "'.join(blockers)))

        missing = []
        for name in state.depends:
            d = self.__get(name)
            if not d.state:
                missing.append(d)
        if missing:
            raise StateDependencyError(
                'State dependency failure for "%s" by: "%s"' % (
                    state.name, '", "'.join(missing)))

    async def on(self, state):
        await self.__get(state).wait(state, True)
        return self

    async def off(self, state):
        await self.__get(state).wait(state, False)
        return self
