# cython: language_level=3, linetrace=True
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
"""Base classes and other functions for the network stack."""
import asyncio
import contextlib
import datetime
import enum
import logging
import random
import uuid
from ipaddress import IPv4Address, IPv6Address
from typing import Tuple, Union, Any, Awaitable

import msgpack
from angelos.bin.nacl import NaCl
from angelos.common.misc import StateMachine, SyncCallable, AsyncCallable
from angelos.document.domain import Node
from angelos.facade.facade import Facade
from angelos.net.noise import NoiseTransportProtocol
from angelos.portfolio.collection import Portfolio

# 1. Packet type, 2 bytes
# 2. Packet length, 3 bytes
# 3. Packet management level, 1 byte
# Packet management levels:
# 1. Session handler
# 2. Service
# 3. Sub service

# There are 10 ranges reserved for services
# 1. 0-127
# 2. 128-255
# 3. 256-383
# 4. 384-511
# 5. 512-639
# 6. 640-767
# 7. 768-895
# 8. 896-1023
# 9. 1024-1151
# 10. 1152-1279
# 512. 65408-65535

# Three types of packet communication ways.
# 1. One way messages
# 2. Communicating states
# 3. Begin and end sessions

EMPTY_PAYLOAD = NaCl.random_bytes(64)

PUSH_ITEM_PACKET = 105
RECEIVED_ITEM_PACKET = 106
PUSH_CHUNK_PACKET = 107
RECEIVED_CHUNK_PACKET = 108
PULL_ITEM_PACKET = 109
SENT_ITEM_PACKET = 110
PULL_CHUNK_PACKET = 111
SENT_CHUNK_PACKET = 112
STOP_ITER_PACKET = 113

ENQUIRY_PACKET = 114  # Ask for information
RESPONSE_PACKET = 115  # Response to enquery

TELL_PACKET = 116  # Tell the state of things
SHOW_PACKET = 117  # Demand to know the state if things
CONFIRM_PACKET = 118  # Accept or deny a state change or proposal

START_PACKET = 119  # Initiate a session
FINISH_PACKET = 120  # Finalize a started session
ACCEPT_PACKET = 121  # Acceptance toward session or request
REFUSE_PACKET = 122  # Refusal of session or request
BUSY_PACKET = 123  # To busy for session or request
DONE_PACKET = 124  # Nothing more to do in session or request

UNKNOWN_PACKET = 125  # Unrecognized packet
ERROR_PACKET = 126  # Technical error
NULL_PACKET = 127  # Synchronous filler packet


class ConfirmCode(enum.IntEnum):
    """Answer codes for ConfirmPackage"""
    YES = 1  # Malformed packet
    NO = 2  # Aborted processing of packet
    NO_COMMENT = 0  # The server or client is busy


class SessionCode(enum.IntEnum):
    """Session future return code for RefusePacket, BusyPacket, AcceptPacket"""
    ACCEPT = 0
    BUSY = 1
    REFUSE = 2
    DONE = 3


class ErrorCode(enum.IntEnum):
    """Error codes"""
    MALFORMED = 1  # Malformed packet
    ABORTED = 2  # Aborted processing of packet
    BUSY = 3  # The server or client is busy
    UNEXPECTED = 4  # Unexpected error


ERROR_CODE_MSG = [
    "None",
    "Malformed packet",
    "Aborted processing of packet",
    "The server or client is busy",
    "Unexpected error"
]


class NetworkError(RuntimeError):
    """Unrepairable network errors. """
    NO_TRANSPORT = ("Transport layer is missing.", 100)
    ALREADY_CONNECTED = ("Already connected.", 101)
    SESSION_NO_SYNC = ("Failed to sync one or several states in session", 102)
    SESSION_TYPE_INCONSISTENCY = ("Session type inconsistent.", 103)
    ATTEMPTED_ATTACK = ("Attempted attack with error/unknown packets.", 104)
    FALSE_CHECK_METHOD = ("State checker not set or of wrong type.", 105)
    NO_PANIC_CORO = ("Panic happened but no emergency button fixed!", 106)


class GotoStateError(RuntimeWarning):
    """When it's not possible to go to a state."""


class NotAuthenticated(RuntimeWarning):
    """When there is not authenticated portfolio."""


class ProtocolNegotiationError(RuntimeWarning):
    """Failed negotiating protcol version."""


def r(i: int) -> Tuple[int, int]:
    """Interval boundaries for given range."""
    return (i - 1) * 128, i * 128 - 1

def ri(n: int) -> int:
    """Range for given number."""
    return n // 128 + 1


class DataType(enum.IntEnum):
    """Custom data types for use with packets and msgpack."""
    UINT = 0x01
    UUID = 0x02
    BYTES_FIX = 0x03
    BYTES_VAR = 0x04
    DATETIME = 0x05


def default(obj: Any) -> msgpack.ExtType:
    """Custom message pack type converter."""
    if isinstance(obj, int):
        return msgpack.ExtType(DataType.UINT, obj.to_bytes(8, "big", signed=False))
    elif isinstance(obj, uuid.UUID):
        return msgpack.ExtType(DataType.UUID, obj.bytes)
    elif isinstance(obj, bytes):
        return msgpack.ExtType(DataType.BYTES_FIX, obj)
    elif isinstance(obj, bytearray):
        return msgpack.ExtType(DataType.BYTES_VAR, bytes(obj))
    elif isinstance(obj, datetime.datetime):
        return msgpack.ExtType(DataType.DATETIME, int(
            datetime.datetime.utcfromtimestamp(
                obj.timestamp()).timestamp()).to_bytes(8, "big", signed=False))
    else:
        raise TypeError("Unsupported code: {}".format(type(obj)))

def ext_hook(code: int, data: bytes) -> Any:
    """Custom message unpack type converter."""
    if code == DataType.UINT:
        return int.from_bytes(data, "big", signed=False)
    elif code == DataType.UUID:
        return uuid.UUID(bytes=data)
    elif code == DataType.BYTES_FIX:
        return data
    elif code == DataType.BYTES_VAR:
        return bytearray(data)
    elif code == DataType.DATETIME:
        return datetime.datetime.fromtimestamp(
            int.from_bytes(data, "big", signed=False)).replace(
            tzinfo=datetime.timezone.utc).astimezone().replace(tzinfo=None)
    return msgpack.ExtType(code, data)


class Packet:
    """Network packet base class.

    Example:
    class MyPacket(Packet, fields=("uint", "uuid", "fixed", "variable", "date"), fields_info=(
            (DataType.UINT, 100, 200), (DataType.UUID,), (DataType.BYTES_FIX, 128), (DataType.BYTES_VAR,),
            (DataType.DATETIME,))):
        pass
    """

    @classmethod
    def __init_subclass__(cls, fields: Tuple[str], fields_info: Tuple[tuple], **kwargs):
        """Add support for fields of certain types."""
        super().__init_subclass__(**kwargs)

        if len(fields) != len(fields_info):
            raise TypeError("Meta information count doesn't match fields count.")

        cls._fields = fields
        cls._fields_info = fields_info

    def __init__(self, *args):
        """Initialize packet with values."""
        if len(args) != len(self._fields):
            raise ValueError("Number of values doesn't match fields count.")

        for index, value in enumerate(args):
            meta = self._fields_info[index]
            code = meta[0]

            if code == DataType.UINT:
                if len(meta) == 3:
                    if not (meta[1] <= value <= meta[2]):
                        raise ValueError("Value not within {0}~{1}: was {2}".format(meta[1], meta[2], value))

            elif code == DataType.BYTES_FIX:
                size = meta[1]
                if len(value) != size:
                    raise ValueError("Wrong size: was {0}, expected {1}".format(size, len(value)))

            elif code == DataType.BYTES_VAR:
                if len(meta) == 3:
                    size = len(value)
                    if not (meta[1] <= size <= meta[2]):
                        raise ValueError("Size not within {0}~{1}: was {2}".format(meta[1], meta[2], size))

            elif code == DataType.DATETIME:
                args = list(args)
                args[index] = value.replace(microsecond=0)

            elif code in (DataType.UUID,):
                pass

            else:
                raise TypeError("Type not implemented: code {}".format(meta[0]))

        self._values = tuple(args)

    @property
    def tuple(self) -> tuple:
        """Expose internal tuple."""
        return self._values

    def __getattr__(self, item: str) -> Any:
        """Read-only access to values via attributes."""
        try:
            return self._values[self._fields.index(item)]
        except ValueError:
            raise AttributeError("Attribute '{}' not found".format(item))

    def __bytes__(self) -> bytes:
        """Pack packet into bytes."""
        return msgpack.packb(self._values, default=default, use_bin_type=True)

    def __repr__(self) -> str:
        fields = list()
        for index in range(len(self._fields)):
            fields.append("{0}={1}".format(self._fields[index], self._values[index]))
        return "({0}: {1})".format(self.__class__.__name__, ", ".join(fields))

    @classmethod
    def unpack(cls, data: bytes) -> "Packet":
        """Unpack data into packet class."""
        return cls(*msgpack.unpackb(data, ext_hook=ext_hook, raw=False))


class EnquiryPacket(Packet, fields=("state", "type", "session"),
                    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Enquire the fact of a state. From client to server."""


class ResponsePacket(Packet, fields=("state", "value", "type", "session"),
                     fields_info=((DataType.UINT,), (DataType.BYTES_VAR, 1, 1024), (DataType.UINT,), (DataType.UINT,))):
    """Respond fact of state enquiry. From server to client."""


class TellPacket(Packet, fields=("state", "value", "type", "session"),
                 fields_info=((DataType.UINT,), (DataType.BYTES_VAR, 1, 1024), (DataType.UINT,), (DataType.UINT,))):
    """Tell the server to set the value of a state. From client to server."""


class ShowPacket(Packet, fields=("state", "type", "session"),
                 fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Request to see the value of a state. From server to client"""


class ConfirmPacket(Packet, fields=("proposal", "answer", "type", "session"),
                    fields_info=((DataType.UINT,), (DataType.UINT, 0, 2), (DataType.UINT,), (DataType.UINT,))):
    """Answer on a sent proposal. 1=Yes, 2=No, 0=No comment. From server to client."""


class StartPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Initiate a packet handler session. Initializer is always the finalizer."""


class FinishPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Finalize a packet handler session."""


class AcceptPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Accept a packet handler session."""


class RefusePacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Refuse a packet handler session."""


class BusyPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Indicate for initiating session packet handler that it is busy asking to come back later."""


class DonePacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Indicate for initiating session packet handler that all is done."""


class PushItemPacket(
    Packet, fields=("count", "item", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.UUID,), (DataType.UINT,), (DataType.UINT,))):
    """Item pushed from client to server."""


class ItemReceivedPacket(
    Packet, fields=("count", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Response to sent item from server."""


class PushChunkPacket(
    Packet, fields=("count", "chunk", "digest", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.BYTES_VAR, 1, 8192), (DataType.BYTES_VAR, 0, 64),
                 (DataType.UINT,), (DataType.UINT,))):
    """Chunk pushed from client to server."""


class ChunkReceivedPacket(
    Packet, fields=("count", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Response to sent chunk from server."""


class PullItemPacket(
    Packet, fields=("count", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Pull item from client to server."""


class ItemSentPacket(
    Packet, fields=("count", "item", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.UUID,), (DataType.UINT,), (DataType.UINT,))):
    """Response to request item from server."""


class PullChunkPacket(
    Packet, fields=("count", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Pull chunk from client to server."""


class ChunkSentPacket(
    Packet, fields=("count", "chunk", "digest", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.BYTES_VAR, 1, 8192), (DataType.BYTES_VAR, 0, 64),
                 (DataType.UINT,), (DataType.UINT,))):
    """Response to request chunk from server."""


class StopIterationPacket(
    Packet, fields=("count", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Response that iteration stopped in any direction."""


class UnknownPacket(Packet, fields=("type", "level", "process"),
                    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Unknown packet."""


class ErrorPacket(Packet, fields=("type", "level", "process", "error"),
                  fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Error packet."""


class NullPacket(
    Packet, fields=("even", "dummy", "type", "session"),
    fields_info=((DataType.UINT,), (DataType.BYTES_VAR, 1, 64), (DataType.UINT,), (DataType.UINT,))):
    """Null packet, used to even out asynchronous communication to synchronous."""


class WaypointState(StateMachine):
    """A state machine that allows switching between states according to predefined paths."""

    def __init__(self, states: dict):
        StateMachine.__init__(self)
        self._options = states

    @property
    def available(self) -> tuple:
        """Expose available options."""
        return self._options[self._state]

    def goto(self, state: str):
        """Go to another state that is available."""
        if state not in self._options[self._state]:
            raise GotoStateError("State '{0}' not among options {1} in '{2}'".format(
                state, self._options[self._state], self._state))
        self._state = state


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
    """Network state in a network protocol, for sharing and carrying out state primitive operations."""

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

    async def eval(self, value: bytes, sesh: "NetworkSession" = None) -> int:
        """Check value and set if yes."""
        if self._frozen:  # Never evaluate or assign if frozen.
            raise ReuseStateError("Attempted reuse of frozen state.")

        if isinstance(self._checker, AsyncCallable):
            answer = await self._checker(value, sesh)
        elif isinstance(self._checker, SyncCallable):
            answer = self._checker(value, sesh)
        elif self._checker is None:
            answer = ConfirmCode.YES
        else:
            raise NetworkError(*NetworkError.FALSE_CHECK_METHOD)

        if answer == ConfirmCode.YES:  # Assign if YES
            self._value = value
            if self._mode == StateMode.MEDIATE:  # Freeze if MEDIATE
                self._frozen = True

        if self._mode == StateMode.ONCE:  # Always freeze if ONCE
            self._frozen = True

        return answer

    async def trigger(self, state: "NetworkState", sesh: "NetworkSession" = None) -> int:
        """Trigger the checker only when FACT and on server."""
        if not (self._frozen and StateMode.FACT):
            raise ReuseStateError("Attempted reuse of frozen state.")

        if isinstance(self._checker, AsyncCallable):
            answer = await self._checker(state, sesh)
        elif isinstance(self._checker, SyncCallable):
            answer = self._checker(state, sesh)
        elif self._checker is None:
            answer = ConfirmCode.YES
        else:
            raise NetworkError(*NetworkError.FALSE_CHECK_METHOD)

        return answer


class SessionInconsistencyWarning(RuntimeWarning):
    """Sessions of same ID is of different type."""


class NetworkSession(WaypointState):
    """Session that run within a protocol handler with states."""

    def __init__(self, handler: "Handler", server: bool, type: int, id: int, states: dict):
        WaypointState.__init__(self, {
            "ready": ("start",),
            "start": ("finish", "done"),
            "done": ("finish",),
            "finish": ("accomplished",),
            "accomplished": tuple(),
        } if server else {
            "ready": ("start",),
            "start": ("accept", "refuse", "done", "busy"),
            "accept": ("finish", "done"),
            "done": ("finish",),
            "refuse": ("accomplished",),
            "busy": ("accomplished",),
            "finish": ("accomplished",),
            "accomplished": tuple(),
        })
        self._handler = handler
        self._state = "ready"

        self._type = type
        self._id = id
        self._states = dict()
        for key in states:
            self._states[key] = NetworkState(server, *states[key])

        self._event = asyncio.Event()
        self._event.clear()
        self._result = None

    @property
    def type(self) -> int:
        """Session type."""
        return self._type

    @property
    def id(self) -> int:
        """Session id."""
        return self._id

    @property
    def states(self) -> dict:
        """Expose the sessions states."""
        return self._states

    async def set_result(self, value: Any):
        """Set result and return to waiter."""
        self._result = value
        self._event.set()

    async def wait(self) -> Any:
        """Wait for result from processor."""
        self._result = None
        await self._event.wait()
        return self._result


class IteratorInconsistencyWarning(RuntimeWarning):
    """Iterator session out of order."""


class ChunkError(RuntimeWarning):
    """Block data digest mismatch."""
    pass


class NetworkIterator(NetworkSession):
    ST_COUNT = 0x01

    def __init__(self, handler: "Handler", server: bool, type: int, id: int, states: dict):
        NetworkSession.__init__(self, handler, server, type, id, states)

        self._iter = asyncio.Condition()
        self._data = None
        self._cnt = 0

    @property
    def iter(self) -> asyncio.Condition:
        """Iterator condition."""
        return self._iter

    @property
    def count(self) -> int:
        """Show count."""
        return self._cnt

    def increase(self):
        """Increase count by one."""
        self._cnt += 1

    async def iter_result(self, data: Any):
        """Set iterator item/chunk and return to waiter."""
        self._data = data
        async with self._iter:
            self._iter.notify()

    async def iter_wait(self) -> Any:
        """Wait for iterator item/chunk from processor."""
        self._data = None
        async with self._iter:
            await self._iter.wait()
        return self._data


class PullIterator(NetworkIterator):
    def __init__(self, handler: "Handler", server: bool, type: int, id: int, states: dict, count: int = 0,
                 check: SyncCallable = None):
        NetworkIterator.__init__(self, handler, server, type, id, {
            **states,
            self.ST_COUNT: (StateMode.FACT, count.to_bytes(4, byteorder="big", signed=False) if count else b"!", check)
        })


class PushIterator(NetworkIterator):
    def __init__(self, handler: "Handler", server: bool, type: int, id: int, states: dict, count: int = 0,
                 check: SyncCallable = None):
        NetworkIterator.__init__(self, handler, server, type, id, {
            **states,
            self.ST_COUNT: (StateMode.ONCE, count.to_bytes(4, byteorder="big", signed=False) if count else b"!", check)
        })


class PullItemIterator(PullIterator):

    async def pull_item(self):
        raise NotImplementedError()


class PushItemIterator(PushIterator):

    async def push_item(self, packet: PushItemPacket):
        raise NotImplementedError()


class PullChunkIterator(PullIterator):

    async def pull_chunk(self):
        raise NotImplementedError()


class PushChunkIterator(PushIterator):

    async def push_chunk(self):
        raise NotImplementedError()


class Handler:
    """Base handler of protocol source of services."""

    logger = logging.getLogger("net.handler")

    LEVEL = 0
    RANGE = 0

    PKT_ENQUIRY = ENQUIRY_PACKET  # Ask for the state of things
    PKT_RESPONSE = RESPONSE_PACKET  # Respond to enquiry
    PKT_TELL = TELL_PACKET  # Tell the state of things
    PKT_SHOW = SHOW_PACKET  # Demand to know the state if things
    PKT_CONFIRM = CONFIRM_PACKET  # Accept or deny a state change or proposal
    PKT_START = START_PACKET  # Initiate a session
    PKT_FINISH = FINISH_PACKET  # Finalize a started session
    PKT_ACCEPT = ACCEPT_PACKET  # Acceptance toward session or request
    PKT_REFUSE = REFUSE_PACKET  # Refusal of session or request
    PKT_BUSY = BUSY_PACKET  # To busy for session or request
    PKT_DONE = DONE_PACKET  # Nothing more to do in session or request
    PKT_PUSH_ITEM = PUSH_ITEM_PACKET  # Push item to server.
    PKT_RCVD_ITEM = RECEIVED_ITEM_PACKET
    PKT_PUSH_CHUNK = PUSH_CHUNK_PACKET  # Push item to server.
    PKT_RCVD_CHUNK = RECEIVED_CHUNK_PACKET
    PKT_PULL_ITEM = PULL_ITEM_PACKET
    PKT_SENT_ITEM = SENT_ITEM_PACKET
    PKT_PULL_CHUNK = PULL_CHUNK_PACKET
    PKT_SENT_CHUNK = SENT_CHUNK_PACKET
    PKT_STOP_ITER = STOP_ITER_PACKET
    PKT_UNKNOWN = UNKNOWN_PACKET
    PKT_ERROR = ERROR_PACKET
    PKT_NULL = NULL_PACKET

    def __init__(
        self, manager: "Protocol", states: dict = dict(), sessions: dict = dict(), max_sesh: int = 0):
        self._queue = asyncio.Queue()
        self._r_start = r(self.RANGE)[0]
        self._pkt_type = None
        self._silent = False

        self._manager = manager
        server = self._manager.is_server()

        self._pkgs = {
            self.PKT_ENQUIRY: EnquiryPacket,
            self.PKT_RESPONSE: ResponsePacket,
            self.PKT_TELL: TellPacket,
            self.PKT_SHOW: ShowPacket,
            self.PKT_CONFIRM: ConfirmPacket,
            self.PKT_START: StartPacket,
            self.PKT_FINISH: FinishPacket,
            self.PKT_ACCEPT: AcceptPacket,
            self.PKT_REFUSE: RefusePacket,
            self.PKT_BUSY: BusyPacket,
            self.PKT_DONE: DonePacket,
            self.PKT_PUSH_ITEM: PushItemPacket,
            self.PKT_RCVD_ITEM: ItemReceivedPacket,
            self.PKT_PUSH_CHUNK: PushChunkPacket,
            self.PKT_RCVD_CHUNK: ChunkReceivedPacket,
            self.PKT_PULL_ITEM: PullItemPacket,
            self.PKT_SENT_ITEM: ItemSentPacket,
            self.PKT_PULL_CHUNK: PullChunkPacket,
            self.PKT_SENT_CHUNK: ChunkSentPacket,
            self.PKT_STOP_ITER: StopIterationPacket,
            self.PKT_UNKNOWN: UnknownPacket,
            self.PKT_ERROR: ErrorPacket,
            self.PKT_NULL: NullPacket,
        }
        self._procs = {
            self.PKT_ENQUIRY: "process_enquiry" if server else None,
            self.PKT_RESPONSE: None if server else "process_response",
            self.PKT_TELL: "process_tell" if server else None,
            self.PKT_SHOW: None if server else "process_show",
            self.PKT_CONFIRM: None if server else "process_confirm",
            self.PKT_START: "process_start" if server else None,
            self.PKT_REFUSE: None if server else "process_refuse",
            self.PKT_BUSY: None if server else "process_busy",
            self.PKT_ACCEPT: None if server else "process_accept",
            self.PKT_FINISH: "process_finish" if server else None,
            self.PKT_DONE: None if server else "process_done",
            self.PKT_PUSH_ITEM: "process_pushitem" if server else None,
            self.PKT_RCVD_ITEM: None if server else "process_rcvditem",
            self.PKT_PUSH_CHUNK: "process_pushchunk" if server else None,
            self.PKT_RCVD_CHUNK: None if server else "process_rcvdchunk",
            self.PKT_PULL_ITEM: "process_pullitem" if server else None,
            self.PKT_SENT_ITEM: None if server else "process_sentitem",
            self.PKT_PULL_CHUNK: "process_pullchunk" if server else None,
            self.PKT_SENT_CHUNK: None if server else "process_sentchunk",
            self.PKT_STOP_ITER: "process_stopiter",
            self.PKT_UNKNOWN: "process_unknown",
            self.PKT_ERROR: "process_error",
            self.PKT_NULL: "process_null"  # if server else None,
        }

        self._processor = asyncio.create_task(self.packet_handler())

        self._states = dict()
        for key in states:
            self._states[key] = NetworkState(server, *states[key])

        self._seshs = dict()
        self._sesh_cnt = 0
        self._sesh_max = max_sesh
        self._sessions = dict()
        for key, value in sessions.items():
            self._sessions[key] = value

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

    async def _package(self, pkt_type: int, packet: Packet):
        """Simplifying packet sending."""
        await self._manager.send_packet(pkt_type + self._r_start, self.LEVEL, packet)

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

                pkt_cls = self._pkgs[self._pkt_type]
                proc_name = self._procs[self._pkt_type]
                self.logger.debug("{} HANDLED {} {}".format(
                    "Server" if self._manager.is_server() else "Client", self._pkt_type, proc_name))

                if proc_name in ("process_unknown", "process_error"):
                    self._silent = True  # Don't send error or unknown response packet.

                proc_func = getattr(self, proc_name)
                await proc_func(pkt_cls.unpack(data))
            except (KeyError, AttributeError) as exc:
                self.logger.exception(exc)
                self._manager.unknown(self._pkt_type + self._r_start, self.LEVEL)
            except (ValueError, TypeError) as exc:
                self.logger.exception(exc)
                self._manager.error(ErrorCode.MALFORMED, self._pkt_type + self._r_start, self.LEVEL)
            except Exception as exc:
                self.logger.exception(exc)
                if not self._silent:
                    self._manager.error(ErrorCode.UNEXPECTED, self._pkt_type + self._r_start, self.LEVEL)
            finally:
                self._pkt_type = None
                self._silent = False

    def get_session(self, session: int) -> NetworkSession:
        """Load a given session."""
        return self._seshs[session] if session in self._seshs.keys() else None

    async def _call_mediate(self, state: int, values: list, sesh: "NetworkSession" = None) -> bytes:
        """
        Negotiate value of state using with multiple tell.

        Called from client.
        A protocol primitive.

        List[bytes]
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            for value in values:
                machine.update(value)
                machine.goto("tell")
                await self._package(self.PKT_TELL, TellPacket(
                    state, machine.value, sesh.type if sesh else 0, sesh.id if sesh else 0))
                answer = await machine.wait()
                if answer == ConfirmCode.YES:
                    machine.freeze()
                    break

        return machine.value if answer == ConfirmCode.YES else None

    async def _call_show(self, state: int, sesh: "NetworkSession" = None):
        """
        Request to show the value of a state.

        Called from the server.
        A protocol primitive.
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            machine.goto("show")
            await self._package(self.PKT_SHOW, ShowPacket(state, sesh.type if sesh else 0, sesh.id if sesh else 0))
            answer = await machine.wait()
            await self._package(self.PKT_NULL, NullPacket(
                True, EMPTY_PAYLOAD[:random.randrange(1, 64)], sesh.type, sesh.session))
        return machine.value if answer == ConfirmCode.YES else None

    async def _call_tell(self, state: int, sesh: "NetworkSession" = None) -> bytes:
        """
        Tell value to evaluate in state.

        Called from the client.
        A protocol primitive.
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            machine.goto("tell")
            await self._package(self.PKT_TELL, TellPacket(
                state, machine.value, sesh.type if sesh else 0, sesh.id if sesh else 0))
            answer = await machine.wait()
        return machine.value if answer == ConfirmCode.YES else None

    async def _call_query(self, state: int, sesh: "NetworkSession" = None) -> tuple:
        """
        Query a fact of state.

        Called from the client.
        A protocol primitive.
        """
        machine = sesh.states[state] if sesh else self._states[state]
        with machine.us():
            await self._package(self.PKT_ENQUIRY,
                                EnquiryPacket(state, sesh.type if sesh else 0, sesh.id if sesh else 0))
            return await machine.wait()

    async def _sesh_open(self, type: int, **kwargs) -> NetworkSession:
        """
        Open a new session of certain type.

        Called from the client.
        Part of a protocol primitive.
        """
        self._sesh_cnt += 1

        sesh_data = self._sessions[type]
        sesh = sesh_data[0](self, self._manager.is_server(), self._sesh_cnt, **sesh_data[1], **kwargs)

        if sesh.type != type:
            raise TypeError("Session built in type: {0} not same as requested: {1}.".format(sesh.type, type))
        self._seshs[sesh.id] = sesh

        sesh.goto("start")
        await self._package(self.PKT_START, StartPacket(type, sesh.id))
        result = await sesh.wait()
        return sesh if result == SessionCode.ACCEPT else None

    async def _sesh_close(self, sesh: NetworkSession):
        """
        Stop a running session and clean up.

        Called from the client.
        Part of a protocol primitive.
        """
        sesh.goto("finish")
        await self._package(self.PKT_FINISH, FinishPacket(sesh.type, sesh.id))

        sesh.goto("accomplished")
        del self._seshs[sesh.id]

    async def _sesh_create(self, type: int = 0, session: int = 0) -> NetworkSession:
        """
        Create a new session based on request from client.

        Called from the server.
        Part of a protocol primitive.
        """
        sesh_data = self._sessions[type]
        sesh = sesh_data[0](self, self._manager.is_server(), session, **sesh_data[1])

        if sesh.type != type:
            raise TypeError("Session built in type: {0} not same as requested: {1}.".format(sesh.type, type))
        self._seshs[session] = sesh
        return sesh

    async def _sesh_done(self, sesh: NetworkSession):
        """
        Tell client there is no more to do in session.

        Called from the server.
        Part of a protocol primitive.
        """
        sesh.goto("accomplished")
        await self._package(self.PKT_DONE, DonePacket(sesh.type, sesh.id))

    @contextlib.asynccontextmanager
    async def _sesh_context(self, sesh_type: int, **kwargs):
        """
        Run a protocol session as a context manager with state synchronization.

        Called from the client.
        A protocol primitive.
        """
        sesh = await self._sesh_open(sesh_type, **kwargs)

        try:
            yield sesh
        finally:
            await self._sesh_close(sesh)

    async def _push_item(self, sesh: NetworkIterator, item: uuid.UUID):
        """
        Send an array of items in a for-loop. Sends from client to server.

        Called from the client.
        A protocol primitive.
        """
        sesh.increase()
        await self._package(self.PKT_PUSH_ITEM, PushItemPacket(sesh.count, item, sesh.type, sesh.id))
        return await sesh.iter_wait()

    async def _push_chunk(
            self, sesh: NetworkIterator, chunk: Union[bytes, bytearray], digest: Union[bytes, bytearray]):
        """
        Send an stream of chunks in a for-loop. Sends from client to server.

        Called from the client.
        A protocol primitive.
        """
        sesh.increase()
        await self._package(self.PKT_PUSH_CHUNK, PushChunkPacket(sesh.count, chunk, digest, sesh.type, sesh.id))
        return await sesh.iter_wait()

    async def _iter_pull_item(self, sesh: NetworkIterator, count: int = 0):
        """
        Run an iterator over an array of items. Brings from server to client.

        Called from the client.
        A protocol primitive.
        """
        while True:
            sesh.increase()
            await self._package(self.PKT_PULL_ITEM, PullItemPacket(sesh.count, sesh.type, sesh.id))
            packet = await sesh.iter_wait()
            if packet is None:
                break
            yield packet.item
            if 0 < count == sesh.count:
                break

    async def _iter_pull_chunk(self, sesh: NetworkIterator, count: int = 0):
        """
        Run an iterator over an array of chunks. Brings from server to client.

        Called from the client.
        A protocol primitive.
        """
        while True:
            sesh.increase()
            await self._package(self.PKT_PULL_CHUNK, PullChunkPacket(sesh.count, sesh.type, sesh.id))
            packet = await sesh.iter_wait()
            if packet is None:
                break
            yield packet.chunk, packet.digest
            if 0 < count == sesh.count:
                break

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

        await self._package(self.PKT_TELL, TellPacket(packet.state, value, packet.type, packet.session))

    async def process_tell(self, packet: TellPacket):
        """
        Process a call to set a value for a state.

        Processed on the server.
        A primitive processor of (show/tell).
        """
        try:
            if packet.session:
                sesh = self.get_session(packet.session)
                machine = sesh.states[packet.state]
            else:
                sesh = None
                machine = self._states[packet.state]

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
                    result = await machine.eval(packet.value, sesh)
                    if not who:
                        await machine.set_result(result)

                machine.goto("accomplished")
                machine.reuse()
        except KeyError:
            result = ConfirmCode.NO_COMMENT

        await self._package(self.PKT_CONFIRM, ConfirmPacket(packet.state, result, packet.type, packet.session))

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
        sesh = self.get_session(packet.session) if packet.session else None
        machine = sesh.states[packet.state] if packet.session else self._states[packet.state]

        if machine.check:
            await machine.trigger(machine, sesh)

        await self._package(self.PKT_RESPONSE, ResponsePacket(packet.state, machine.value, packet.type, packet.session))

    async def process_response(self, packet: ResponsePacket):
        """
        Process a response of a fact enquiry.

        Processed on the client.
        A primitive processor of (query).
        """
        if packet.session:
            sesh = self.get_session(packet.session)
            machine = sesh.states[packet.state]
        else:
            sesh = None
            machine = self._states[packet.state]

        if machine.other() != False:  # Them or no-one
            machine.other(reset=True)  # Reset other
        elif machine.mode == StateMode.FACT:  # Us
            await machine.set_result((await machine.eval(packet.value, sesh), packet.value))
        else:
            await machine.set_result((None, packet.value))

    async def process_start(self, packet: StartPacket):
        """Session start requested."""
        if len(self._seshs) >= self._sesh_max:
            await self._package(self.PKT_BUSY, BusyPacket(packet.type, packet.session))
        elif packet.session in self._seshs.keys() or packet.type not in self._sessions.keys():
            await self._package(self.PKT_REFUSE, RefusePacket(packet.type, packet.session))
        else:
            sesh = await self._sesh_create(packet.type, packet.session)
            if not sesh:
                await self._package(self.PKT_REFUSE, RefusePacket(packet.type, packet.session))
            else:
                sesh.goto("start")
                await self._package(self.PKT_ACCEPT, AcceptPacket(packet.type, packet.session))

    async def process_finish(self, packet: FinishPacket):
        """Close an open session."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.goto("finish")
        sesh.goto("accomplished")
        await self._package(self.PKT_NULL, NullPacket(
            True, EMPTY_PAYLOAD[:random.randrange(1, 64)], packet.type, packet.session))
        del self._seshs[packet.session]

    async def process_accept(self, packet: AcceptPacket):
        """Accept response to start session."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.goto("accept")
        await sesh.set_result(SessionCode.ACCEPT)

    async def process_refuse(self, packet: RefusePacket):
        """Refuse response to start session."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.goto("refuse")
        sesh.goto("accomplished")
        sesh.future.set_result(SessionCode.REFUSE)
        del self._seshs[packet.session]

    async def process_busy(self, packet: BusyPacket):
        """Busy response to start session."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.goto("busy")
        sesh.goto("accomplished")
        sesh.future.set_result(SessionCode.BUSY)
        del self._seshs[packet.session]

    async def process_done(self, packet: DonePacket):
        """Indication there is nothing more to do in session."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.event.set()
        sesh.goto("done")
        sesh.cleanup()

    async def process_pushitem(self, packet: PushItemPacket):
        """Handle pushed item from client."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.increase()
        max_iter = sesh.states[NetworkIterator.ST_COUNT].value
        if max_iter != b"!":
            if sesh.count > int.from_bytes(max_iter, "big", signed=False):
                raise IteratorInconsistencyWarning("More items pushed than max.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Pushed item in wrong order.")

        await sesh.push_item(packet.item)
        await self._package(self.PKT_RCVD_ITEM, ItemReceivedPacket(sesh.count, sesh.type, sesh.id))

    async def process_rcvditem(self, packet: ItemReceivedPacket):
        """Handle received item confirmation from server."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Received item confirmation wrong order.")

        await sesh.iter_result(packet)

    async def process_pushchunk(self, packet: PushChunkPacket):
        """Handle pushed chunk from client."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.increase()
        max_iter = sesh.states[NetworkIterator.ST_COUNT].value
        if max_iter != b"!":
            if sesh.count > int.from_bytes(max_iter, "big", signed=False):
                raise IteratorInconsistencyWarning("More chunks pushed than max.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Pushed chunk in wrong order.")

        await sesh.push_chunk(packet.chunk, packet.digest)
        await self._package(self.PKT_RCVD_CHUNK, ChunkReceivedPacket(sesh.count, sesh.type, sesh.id))

    async def process_rcvdchunk(self, packet: ChunkReceivedPacket):
        """Handle received chunk confirmation from server."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Received chunk confirmation wrong order.")

        await sesh.iter_result(packet)

    async def process_pullitem(self, packet: PullItemPacket):
        """Handle item pull request from client."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.increase()
        max_iter = sesh.states[NetworkIterator.ST_COUNT].value
        if max_iter != b"!":
            if sesh.count > int.from_bytes(max_iter, "big", signed=False):
                raise IteratorInconsistencyWarning("More item pushed than max.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Pushed item in wrong order.")

        try:
            item = await sesh.pull_item()
        except StopAsyncIteration:
            await self._package(self.PKT_STOP_ITER, StopIterationPacket(sesh.count, sesh.type, sesh.id))
        else:
            await self._package(self.PKT_SENT_ITEM, ItemSentPacket(sesh.count, item, sesh.type, sesh.id))

    async def process_sentitem(self, packet: ItemSentPacket):
        """Handle sent item from server."""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Pushed chunk in wrong order.")

        await sesh.iter_result(packet)

    async def process_pullchunk(self, packet: PullChunkPacket):
        """Handle chunk pull request from client"""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        sesh.increase()
        max_iter = sesh.states[NetworkIterator.ST_COUNT].value
        if max_iter != b"!":
            if sesh.count > int.from_bytes(max_iter, "big", signed=False):
                raise IteratorInconsistencyWarning("More chunks pushed than max.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Pushed chunk in wrong order.")

        chunk, digest = await sesh.pull_chunk()
        await self._package(self.PKT_SENT_CHUNK, ChunkSentPacket(sesh.count, chunk, digest, sesh.type, sesh.id))

    async def process_sentchunk(self, packet: ChunkSentPacket):
        """Handle sent chunk from server"""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Pushed chunk in wrong order.")

        await sesh.iter_result(packet)

    async def process_stopiter(self, packet: StopIterationPacket):
        """Handle stop iteration from server/client"""
        sesh = self.get_session(packet.session)
        if sesh.type != packet.type:
            raise SessionInconsistencyWarning("Session type inconsistency.")

        if sesh.count != packet.count:
            raise IteratorInconsistencyWarning("Pushed chunk or item in wrong order.")

        await sesh.iter_result(None)

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

    async def process_null(self, packet: NullPacket):
        """Handle a null packet. Null packets are used for fillers to make all communication synchronous."""
        if not packet.even:
            await self._package(self.PKT_NULL, NullPacket(
                True, EMPTY_PAYLOAD[:random.randrange(1, 64)], packet.type, packet.session))


class Protocol(asyncio.Protocol):
    """Protocol for handling packages going from and to packet handlers."""

    logger = logging.getLogger("net.protocol")

    def __init__(
            self, facade: Facade, server: bool = False,
            conn_mgr: "ConnectionManager" = None, emergency: Awaitable = None):
        self._server = server
        self._handlers = dict()
        self._ranges_available = set()
        self._ranges = dict()
        self._facade = facade
        self._conn_mgr = conn_mgr
        self._transport = None
        self._portfolio = None
        self._login = None
        self._node = None

        self._emergency = emergency

        self._trans_fut = asyncio.get_event_loop().create_future()

    @property
    def facade(self) -> Facade:
        """Expose the facade."""
        return self._facade

    @property
    def transport(self) -> asyncio.Transport:
        """Expose underlying transport."""
        return self._transport

    @property
    def portfolio(self) -> Portfolio:
        """Expose connecting portfolio."""
        if not self._portfolio:
            raise NotAuthenticated("No authenticated portfolio.")
        return self._portfolio

    @property
    def conn_mgr(self) -> "ConnectionManager":
        """Expose the connection manager."""
        return self._conn_mgr

    def panic(self, severity: object):
        """Handlers can trigger panic if something goes seriously wrong."""
        if not self._emergency:
            raise NetworkError(*NetworkError.NO_PANIC_CORO)
        self.logger.error("Panic happened.")
        asyncio.run_coroutine_threadsafe(self._emergency(severity, self), asyncio.get_running_loop())

    async def ready(self):
        """Wait for the underlying transport to be ready."""
        await self._trans_fut

    def is_server(self) -> bool:
        """Whether is a server."""
        return self._server

    def get_handler(self, range: int) -> Handler:
        """Get packet handler for given range if available or None."""
        return self._ranges[range] if range in self._ranges_available else None

    def _add_handler(self, service: Handler):
        if service.LEVEL not in self._handlers.keys():
            self._handlers[service.LEVEL] = set()
        level = self._handlers[service.LEVEL]
        level.add(service)

        self._ranges_available.add(service.RANGE)
        self._ranges[service.RANGE] = service

    def authentication_made(self, portfolio: Portfolio, login_type: bytes, node: Union[bool, Node]):
        """Indicate that authentication has taken place. Never call from outside, internal use only."""
        self._portfolio = portfolio
        self._login = login_type
        self._node = node

    def authorization_made(self):
        """Indicate that authorization has been made after authentication.
        This is called from the server only. Leave empty."""
        pass

    def connection_made(self, transport: asyncio.Transport):
        """Connection is made."""
        self._transport = transport
        self._trans_fut.set_result(True)

    def connection_lost(self, exc: Exception):
        """Clean up."""
        self._cleanup()

        if exc:
            self.panic(exc)
        else:
            self.panic(True)

    def data_received(self, data: bytes):
        """Data received."""
        while data:

            pkt_type = 0
            pkt_level = 0
            try:
                meta = data[0:6]
                data = data[6:]

                pkt_type = int.from_bytes(meta[0:2], "big")
                pkt_length = int.from_bytes(meta[2:5], "big")
                pkt_level = int(meta[5])

                chunk = data[0:(pkt_length - 6)]
                data = data[(pkt_length - 6):]

                pkt_range = ri(pkt_type)
                handler = self._ranges[pkt_range]
            except KeyError as exc:
                low = r(pkt_range)[0]
                if pkt_type == low + UNKNOWN_PACKET or pkt_type == low + ERROR_PACKET:
                    self.logger.critical("Attempted attack: error package infinite loop.")  # Attempted attack
                    raise NetworkError(*NetworkError.ATTEMPTED_ATTACK)
                else:
                    self.unknown(pkt_type, pkt_level)
            except ValueError:
                self.error(ErrorCode.MALFORMED, pkt_type, pkt_level)
            else:
                if handler.queue.full():
                    self.error(ErrorCode.BUSY, pkt_type + r(pkt_range)[0], self.LEVEL)
                else:
                    handler.queue.put_nowait((pkt_type, chunk))

    def eof_received(self) -> bool:
        """Information of other side wanting to close."""
        self._cleanup()
        return False

    async def send_packet(self, pkt_type: int, pkt_level: int, packet: Packet):
        """Send packet over socket."""
        if not self._transport:
            raise NetworkError(*NetworkError.NO_TRANSPORT)

        await self._transport.wait()

        self.logger.debug("{} SENT {} {}".format("Server" if self.is_server() else "Client", pkt_type, packet))

        data = bytes(packet)
        self._transport.write(
            pkt_type.to_bytes(2, "big") +
            (6 + len(data)).to_bytes(3, "big") +
            pkt_level.to_bytes(1, "big") +
            data
        )

    def _send_packet_async(self, pkt_type: int, pkt_level: int, packet: Packet):
        def done(fut):
            fut.result()

        task = asyncio.create_task(self.send_packet(pkt_type, pkt_level, packet))
        task.add_done_callback(done)

    def unknown(self, pkt_type: int, pkt_level: int, process: int = 0):
        """Unknown packet is returned to sender."""
        self._send_packet_async(
            r(ri(pkt_type))[0] + UNKNOWN_PACKET, pkt_level,
            UnknownPacket(pkt_type, pkt_level, process)
        )

    def error(self, error: int, pkt_type: int, pkt_level, process: int = 0):
        """Error happened is returned to sender."""
        self._send_packet_async(
            r(ri(pkt_type))[0] + ERROR_PACKET, pkt_level,
            ErrorPacket(pkt_type, pkt_level, process, error)
        )

    def _cleanup(self):
        for handler in self._ranges.values():
            if not handler.processor.done():
                handler.queue.put_nowait(None)


class ClientProtoMixin:
    """Client of packet manager."""

    def connection_lost(self, exc: Exception):
        """Clean up."""
        self.close()

    @classmethod
    async def connect(
            cls, facade: Facade, host: Union[str, IPv4Address, IPv6Address], port: int,
            emergency: Awaitable = None, key: bytes = None) -> "Protocol":
        """Connect to server."""
        a, protocol = await asyncio.get_running_loop().create_connection(
            lambda: NoiseTransportProtocol(cls(facade, emergency=emergency), server=False, key=key), str(host), port)
        return protocol.get_protocol()


class ServerProtoMixin:
    """Server of packet manager."""

    def eof_received(self):
        """End of communication."""
        if self.conn_mgr:
            self.conn_mgr.remove(self)

    def connection_made(self, transport: asyncio.Transport):
        """Connection is made."""
        if self._conn_mgr:
            self._conn_mgr.add(self)

    def connection_lost(self, exc: Exception):
        """Clean up."""
        if self.conn_mgr:
            self.conn_mgr.remove(self)
        self.close()

    @classmethod
    async def listen(
            cls, facade: Facade, host: Union[str, IPv4Address, IPv6Address],
            port: int, connections: "ConnectionManager" = None, emergency: Awaitable = None, key: bytes = None
    ) -> asyncio.base_events.Server:
        """Start a listening server."""
        return await asyncio.get_running_loop().create_server(
            lambda: NoiseTransportProtocol(
                cls(facade, connections, emergency=emergency), server=True, key=key), host, port)


class ConnectionManager:
    """Keeps track of connections with server protocols."""

    def __init__(self):
        self._client_instances = dict()
        self._clients = set()

    def __iter__(self):
        for client in self._clients:
            yield self._client_instances[client]

    def add(self, proto: ServerProtoMixin):
        """Add server protocol connection."""
        pid = id(proto)
        if pid in self._clients:
            raise NetworkError(*NetworkError.ALREADY_CONNECTED)
        self._clients.add(pid)
        self._client_instances[pid] = proto

    def remove(self, proto: ServerProtoMixin):
        """Remove server protocol connection"""
        pid = id(proto)

        if pid in self._client:
            del self._client_instances[pid]
            self._clients.remove(pid)
