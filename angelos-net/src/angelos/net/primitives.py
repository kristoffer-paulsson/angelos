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
"""Network protocol handler primitives"""
import asyncio
import contextlib
import enum
from typing import Any

from angelos.common.misc import SyncCallable, AsyncCallable
from angelos.common.utils import Util
from angelos.net.base import UNKNOWN_PACKET, ERROR_PACKET, UnknownPacket, ErrorPacket, r, Packet, ErrorCode, \
    WaypointState, ProtocolSession, ConfirmCode, NetworkError, \
    GotoStateError, ENQUIRY_PACKET, RESPONSE_PACKET, TELL_PACKET, SHOW_PACKET, CONFIRM_PACKET, EnquiryPacket, \
    ResponsePacket, TellPacket, ShowPacket, ConfirmPacket


class Handler:
    """Base handler of protocol source of services."""

    LEVEL = 0
    RANGE = 0

    PKT_UNKNOWN = UNKNOWN_PACKET
    PKT_ERROR = ERROR_PACKET

    PACKETS = dict()
    PROCESS = dict()

    def __init__(self, manager: "Protocol"):
        self._queue = asyncio.Queue()
        self._r_start = r(self.RANGE)[0]
        self._pkt_type = None
        self._silent = False

        self._manager = manager

        self.PACKETS = {
            self.PKT_UNKNOWN: UnknownPacket,
            self.PKT_ERROR: ErrorPacket,
            **self.PACKETS
        }
        self.PROCESS = {
            self.PKT_UNKNOWN: "process_unknown",
            self.PKT_ERROR: "process_error",
            **self.PROCESS
        }

        self._processor = asyncio.create_task(self.packet_handler())

    @property
    def manager(self) -> "Protocol":
        """Expose the packet manager."""
        return self._manager

    @property
    def queue(self) -> asyncio.Queue:
        """Expose current queue."""
        return self._queue

    @property
    def processor(self) -> asyncio.Task:
        """Expose current task."""
        return self._processor

    @property
    def states(self) -> dict:
        """Expose local states."""
        return self._states

    def _package(self, pkt_type: int, packet: Packet):
        """Simplifying packet sending."""
        self._manager.send_packet(pkt_type + self._r_start, self.LEVEL, packet)

    async def packet_handler(self):
        """Handle received packet.

        If packet type class, method or processor isn't found
        An unknown packet is returned to the senders handler.
        """
        while True:
            item = await self._queue.get()
            if isinstance(item, type(None)):
                break
            try:
                self._pkt_type, data = item
                self._pkt_type = self._pkt_type - self._r_start

                pkt_cls = self.PACKETS[self._pkt_type]
                proc_name = self.PROCESS[self._pkt_type]
                print("HANDLE", "Server" if self._manager.is_server() else "Client", self._pkt_type, proc_name)

                if proc_name in ("process_unknown", "process_error"):
                    self._silent = True  # Don't send error or unknown response packet.

                proc_func = getattr(self, proc_name)
                await proc_func(pkt_cls.unpack(data))
            except (KeyError, AttributeError) as exc:
                Util.print_exception(exc)
                self._manager.unknown(self._pkt_type + self._r_start, self.LEVEL)
            except (ValueError, TypeError) as exc:
                Util.print_exception(exc)
                self._manager.error(ErrorCode.MALFORMED, self._pkt_type + self._r_start, self.LEVEL)
            except Exception as exc:
                Util.print_exception(exc)
                if not self._silent:
                    self._manager.error(ErrorCode.UNEXPECTED, self._pkt_type + self._r_start, self.LEVEL)
            finally:
                self._pkt_type = None
                self._silent = False

    async def process_unknown(self, packet: UnknownPacket):
        """Handle an unknown packet response.

        This method MUST never return an unknown or error in order
        to prevent an infinite loop over the network.
        """
        raise NotImplementedError()

    async def process_error(self, packet: ErrorPacket):
        """Handle an error packet response.

        This method MUST never return an unknown or error in order
        to prevent an infinite loop over the network.
        """
        raise NotImplementedError()


#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####
#### #### #### #### #### #### ## Network state ## #### #### #### #### #### ####
#### #### #### #### #### #### #### #### #### #### #### #### #### #### #### ####


class NetworkSession:
    pass


class StateMode(enum.IntEnum):
    """
    A state can operate in several modes:

    * ONCE: Allows to tell and show one time.
    * REPRISE: Allows tell multiple times.
    * MEDIATE: Allows tell until a yes confirmation.
    * FACT: Entry state that can't be showed or told.
    """
    ONCE = 0
    REPRISE = 1
    MEDIATE = 2
    FACT = 3


class GrabStateError(RuntimeError):
    """A state primitive or processor is wrongfully seized or unoccupied."""


class ReuseStateError(RuntimeError):
    """A state was not tellable."""


class FrozenStateError(RuntimeWarning):
    """Attempted change of frozen state."""


class NetworkState(WaypointState):

    def __init__(self, server: bool, mode: int, value: bytes = None, check: SyncCallable = None):

        # Related to the state machine
        WaypointState.__init__(self, {
            "ready": ("show", "tell"),
            "show": ("tell",),
            "tell": ("accomplished",),
            "accomplished": tuple(),
        } if server else {
            "ready": ("tell", "show"),
            "show": ("confirm",),
            "tell": ("confirm",),
            "confirm": ("accomplished",),
            "accomplished": tuple(),
        })
        self._state = "ready"

        # Locking mechanism
        self._loop = asyncio.get_event_loop()
        self._condition = asyncio.Condition()
        self._result = None
        self._other = None

        # Mode, value and evaluation
        self._mode = mode
        self._value = value
        self._checker = check
        self._frozen = True if self._mode == StateMode.FACT and server else False  # Frozen if FACT and server-side.

    @property
    def mode(self) -> int:
        """State mode."""
        return self._mode

    @property
    def value(self) -> bytes:
        """State value."""
        return self._value

    @property
    def check(self) -> bool:
        """Evaluation checker set."""
        return bool(self._checker)

    @property
    def frozen(self) -> bool:
        """Frozen machine."""
        return self._frozen

    def __enter__(self):
        """Grab state."""
        if self._other is None:
            raise GrabStateError("State not properly grabbed.")
        return None

    def __exit__(self, exc_type, exc, tb):
        """Release state."""
        self.other(reset=True)

    def us(self) -> "NetworkState":
        """Grab user predicate as us, other = False."""
        if self._other is not None:
            raise GrabStateError("State already grabbed.")
        self._other = False
        return self

    def them(self) -> "NetworkState":
        """Grab user predicate as them, other = True."""
        if self._other is not None:
            raise GrabStateError("State already grabbed.")
        self._other = True
        return self

    async def set_result(self, value: Any):
        """Set result and return to waiter."""
        self._result = value
        async with self._condition:
            self._condition.notify()

    async def wait(self) -> Any:
        """Wait for result from processor."""
        self._result = None
        async with self._condition:
            await self._condition.wait()
        return self._result

    def other(self, reset: bool = False) -> bool:
        """Used by the other side."""
        if reset:
            if self._other is None:
                raise GrabStateError("Attempt to release non-grabbed state.")
            self._other = None
        else:
            return self._other

    def freeze(self):
        """Freeze state"""
        self._frozen = True

    def update(self, value: bytes):
        """Update value field."""
        self._value = value

    def upgrade(self, check: SyncCallable):
        """Upgrade checker."""
        self._checker = check

    def reuse(self):
        """Reuse state if possible."""
        if not self._frozen:
            self._state = "ready"

    async def eval(self, value: bytes) -> int:
        """Check value and set if yes."""
        if self._frozen:  # Never evaluate or assign if frozen.
            raise ReuseStateError("Attempted reuse of frozen state.")

        if isinstance(self._checker, AsyncCallable):
            answer = await self._checker(value)
        elif isinstance(self._checker, SyncCallable):
            answer = self._checker(value)
        else:
            raise NetworkError(*NetworkError.FALSE_CHECK_METHOD)

        if answer == ConfirmCode.YES:  # Assign if YES
            self._value = value
            if self._mode == StateMode.MEDIATE:  # Freeze if MEDIATE
                self._frozen = True

        if self._mode == StateMode.ONCE:  # Always freeze if ONCE
            self._frozen = True

        return answer


class StateMixin:
    """State mixin for a network protocol handler, adding state exchange as a primitive."""

    _TELLABLE = (StateMode.ONCE, StateMode.REPRISE, StateMode.MEDIATE)

    PKT_ENQUIRY = ENQUIRY_PACKET  # Ask for the state of things
    PKT_RESPONSE = RESPONSE_PACKET  # Respond to enquiry
    PKT_TELL = TELL_PACKET  # Tell the state of things
    PKT_SHOW = SHOW_PACKET  # Demand to know the state if things
    PKT_CONFIRM = CONFIRM_PACKET  # Accept or deny a state change or proposal

    def __init__(self, states: dict):
        """Dict[int: Tuple[int, bytes, SyncCallable]]"""
        server = self._manager.is_server()
        self.PACKETS = {
            self.PKT_ENQUIRY: EnquiryPacket,
            self.PKT_RESPONSE: ResponsePacket,
            self.PKT_TELL: TellPacket,
            self.PKT_SHOW: ShowPacket,
            self.PKT_CONFIRM: ConfirmPacket,
            **self.PACKETS
        }
        self.PROCESS = {
            self.PKT_ENQUIRY: "process_enquiry" if server else None,
            self.PKT_RESPONSE: None if server else "process_response",
            self.PKT_TELL: "process_tell" if server else None,
            self.PKT_SHOW: None if server else "process_show",
            self.PKT_CONFIRM: None if server else "process_confirm",
            **self.PROCESS
        }
        self._states = self._init_states(states)

    def _init_states(self, states: dict) -> dict:
        """Initialize state machines according to description.

        Dict[int: Tuple[int, bytes, SyncCallable]]
        Dict[int: NetworkState]
        """
        server = self._manager.is_server()
        init = dict()
        for key in states:
            init[key] = NetworkState(server, *states[key])
        return init

    async def _call_mediate(self, state: int, values: list, sesh: ProtocolSession = None) -> bytes:
        """
        Negotiate value of state with multiple tell.

        Called from client.
        A protocol primitive.

        List[bytes]
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            for value in values:
                machine.update(value)
                machine.goto("tell")
                self._package(self.PKT_TELL, TellPacket(
                    state, machine.value, sesh.type if sesh else 0, sesh.id if sesh else 0))
                answer = await machine.wait()
                if answer == ConfirmCode.YES:
                    machine.freeze()
                    break

        return machine.value if answer == ConfirmCode.YES else None

    async def _call_show(self, state: int, sesh: ProtocolSession = None):
        """
        Request to show the value of a state.

        Called from the server.
        A protocol primitive.
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            machine.goto("show")
            self._package(self.PKT_SHOW, ShowPacket(state, sesh.type if sesh else 0, sesh.id if sesh else 0))
            answer = await machine.wait()
        return machine.value if answer == ConfirmCode.YES else None

    async def _call_tell(self, state: int, sesh: ProtocolSession = None) -> int:
        """
        Tell value to evaluate in state.

        Called from the client.
        A protocol primitive.
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            machine.goto("tell")
            self._package(self.PKT_TELL, TellPacket(
                state, machine.value, sesh.type if sesh else 0, sesh.id if sesh else 0))
            answer = await machine.wait()
        return machine.value if answer == ConfirmCode.YES else None

    async def _call_query(self, state: int, sesh: ProtocolSession = None) -> tuple:
        """
        Query a fact of state.

        Called from the client.
        A protocol primitive.
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            self._package(self.PKT_ENQUIRY, EnquiryPacket(state, sesh.type if sesh else 0, sesh.id if sesh else 0))
            return await machine.wait()

    async def process_show(self, packet: ShowPacket):
        """
        Process request to see a value of a state.

        Processed on the client.
        A primitive processor of (show).
        """
        try:
            machine = self.get_session(packet.session).states[packet.state] \
                if packet.session else self._states[packet.state]

            if machine.mode in (StateMode.MEDIATE, StateMode.REPRISE, StateMode.FACT):
                raise ReuseStateError("Forbidden use of state.")

            machine.them()
            machine.goto("show")
            value = machine.value
        except KeyError:
            value = b"?"

        self._package(self.PKT_TELL, TellPacket(packet.state, value, packet.type, packet.session))

    async def process_tell(self, packet: TellPacket):
        """
        Process a call to set a value for a state.

        Processed on the server.
        A primitive processor of (show/tell).
        """
        try:
            machine = self.get_session(packet.session).states[packet.state] \
                if packet.session else self._states[packet.state]

            who = machine.other()
            # If True or None use with statement.
            # Possible primitives MEDIATE and TELL if True.
            # Only possible primitive should be SHOW if False.
            # None will trigger predicate for termination.
            # Types may be ONCE, REPRISE or MEDIATE.
            with machine.them() if who is not False else contextlib.nullcontext():
                machine.goto("tell")

                if packet.value == b"?":  # or not machine.check:
                    result = ConfirmCode.NO_COMMENT
                else:
                    result = await machine.eval(packet.value)
                    if not who:
                        await machine.set_result(result)

                machine.goto("accomplished")
                machine.reuse()
        except KeyError:
            result = ConfirmCode.NO_COMMENT

        self._package(self.PKT_CONFIRM, ConfirmPacket(packet.state, result, packet.type, packet.session))

    async def process_confirm(self, packet: ConfirmPacket):
        """
        Process an answer for acceptance of a value for a state.

        Processed on the client.
        A primitive processor of (show/tell).
        """
        try:
            machine = self.get_session(packet.session).states[packet.proposal] \
                if packet.session else self._states[packet.proposal]

            machine.goto("confirm")
            if machine.other():  # Them
                machine.other(reset=True)  # Reset other
            else:  # Us or no-one
                await machine.set_result(packet.answer)
            machine.goto("accomplished")

            if machine.mode == StateMode.ONCE or (
                    machine.mode == StateMode.MEDIATE and packet.answer == ConfirmCode.YES):
                machine.freeze()

            machine.reuse()

        except KeyError:
            if packet.answer != ConfirmCode.NO_COMMENT:
                raise
        except GotoStateError:
            raise

    async def process_enquiry(self, packet: EnquiryPacket):
        """
        Process an enquiry for a fact of a state.

        Processed on the server.
        A primitive processor of (query).
        """
        machine = self.get_session(packet.session).states[packet.state] \
            if packet.session else self._states[packet.state]

        self._package(self.PKT_RESPONSE, ResponsePacket(packet.state, machine.value, packet.type, packet.session))

    async def process_response(self, packet: ResponsePacket):
        """
        Process a response of a fact enquiry.

        Processed on the client.
        A primitive processor of (query).
        """
        machine = self.get_session(packet.session).states[packet.state] \
            if packet.session else self._states[packet.state]

        if machine.other() != False:  # Them or no-one
            machine.other(reset=True)  # Reset other
        elif machine.mode == StateMode.FACT:  # Us
            await machine.set_result((await machine.eval(packet.value), packet.value))
        else:
            await machine.set_result((None, packet.value))
