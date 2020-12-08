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
"""Base classes and other functions for the network stack."""
import asyncio
import datetime
import enum
import struct
import uuid
from asyncio import CancelledError, InvalidStateError
from ipaddress import IPv4Address, IPv6Address
from typing import Tuple, Union, Any

import msgpack
from angelos.common.misc import StateMachine
from angelos.common.utils import Util
from angelos.document.domain import Node
from angelos.facade.facade import Facade
from angelos.portfolio.collection import Portfolio

# 1. Packet type, 2 bytes
# 2. Packet length, 3 bytes
# 3. Packet management level, 1 byte
# Packet management levels:
# 1. Session handler
# 2. Service
# 3. Sub service

# Template for custom transport.
#  https://docs.zombofant.net/aioopenssl/devel/_modules/aioopenssl.html#STARTTLSTransport
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

TELL_PACKET = 117  # Tell the state of things
SHOW_PACKET = 118  # Demand to know the state if things
CONFIRM_PACKET = 119  # Accept or deny a state change or proposal

START_PACKET = 120  # Initiate a session
FINISH_PACKET = 121  # Finalize a started session
ACCEPT_PACKET = 122  # Acceptance toward session or request
REFUSE_PACKET = 123  # Refusal of session or request
BUSY_PACKET = 124  # To busy for session or request
DONE_PACKET = 125  # Nothing more to do in session or request
UNKNOWN_PACKET = 126  # Unrecognized packet
ERROR_PACKET = 127  # Technical error


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


class NetworkError(RuntimeError):
    """Unrepairable network errors. """
    NO_TRANSPORT = ("Transport layer is missing.", 100)
    ALREADY_CONNECTED = ("Already connected.", 101)


class GotoStateError(RuntimeWarning):
    """When it's not possible to go to a state."""


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

    @classmethod
    def unpack(cls, data: bytes) -> "Packet":
        """Unpack data into packet class."""
        return cls(*msgpack.unpackb(data, ext_hook=ext_hook, raw=False))


class TellPacket(Packet, fields=("state", "value", "type", "session"),
                 fields_info=((DataType.UINT,), (DataType.BYTES_VAR, 1, 1024), (DataType.UINT,), (DataType.UINT,))):
    """Tell the state of a thing. Client/server"""


class ShowPacket(Packet, fields=("state", "type", "session"),
                 fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Get the state of a thing. Client/server"""


class ConfirmPacket(Packet, fields=("proposal", "answer", "type", "session"),
                    fields_info=((DataType.UINT,), (DataType.UINT, 0, 2), (DataType.UINT,), (DataType.UINT,))):
    """Answer on a sent proposal. 1=Yes, 2=No, 0=No comment."""


class StartPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Initiate a packet handler session. Initializer is always the finalizer."""


class FinishPacket(Packet, fields=("type", "session"), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Finalize a packet handler session."""


class AcceptPacket(Packet, fields=("type", "session",), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Accept a packet handler session."""


class RefusePacket(Packet, fields=("type", "session",), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Refuse a packet handler session."""


class BusyPacket(Packet, fields=("type", "session",), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Indicate for initiating session packet handler that it is busy asking to come back later."""


class DonePacket(Packet, fields=("type", "session",), fields_info=((DataType.UINT,), (DataType.UINT,))):
    """Indicate for initiating session packet handler that all is done."""


class UnknownPacket(Packet, fields=("type", "level", "process"),
                    fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Unknown packet."""


class ErrorPacket(Packet, fields=("type", "level", "process", "error"),
                  fields_info=((DataType.UINT,), (DataType.UINT,), (DataType.UINT,), (DataType.UINT,))):
    """Error packet."""


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
            raise GotoStateError("State '{0}' not among options {1}".format(state, self._options[self._state]))
        self._state = state


class ClientStateExchangeMachine(WaypointState):
    """Waypoints for exchanging a state over a protocol."""

    def __init__(self):
        self.answer = None
        self._event = asyncio.Event()
        WaypointState.__init__(self, {
            "ready": ("tell", "show"),
            "show": ("confirm",),
            "tell": ("confirm",),
            "confirm": ("accomplished",),
            "accomplished": tuple(),
        })
        self._state = "ready"

    @property
    def event(self) -> asyncio.Event:
        """Expose event."""
        return self._event


class ServerStateExchangeMachine(WaypointState):
    """Waypoints for exchanging a state over a protocol."""

    def __init__(self):
        self._condition = asyncio.Condition()
        self.check = lambda value: ConfirmCode.YES
        self.value = None
        WaypointState.__init__(self, {
            "ready": ("show", "tell"),
            "show": ("tell",),
            "tell": ("accomplished",),
            "accomplished": tuple(),
        })
        self._state = "ready"

    @property
    def condition(self) -> asyncio.Condition:
        """Expose condition."""
        return self._condition

    def predicate(self) -> bool:
        """Condition predicate true if confirmation is yes."""
        return True if self.evaluate() == ConfirmCode.YES else False

    def evaluate(self) -> int:
        """Evaluate value."""
        return self.check(self.value)


class ClientSessionStateMachine(WaypointState):
    """Waypoints for setting session mode over a protocol."""

    def __init__(self):
        self._future = asyncio.get_event_loop().create_future()
        self._event = asyncio.Event()
        WaypointState.__init__(self, {
            "ready": ("start",),
            "start": ("accept", "refuse", "done", "busy"),
            "accept": ("finish", "done"),
            "done": ("finish",),
            "refuse": ("accomplished",),
            "busy": ("accomplished",),
            "finish": ("accomplished",),
            "accomplished": tuple(),
        })
        self._state = "ready"

    @property
    def future(self) -> asyncio.Future:
        return self._future

    @property
    def event(self) -> asyncio.Event:
        """Expose event."""
        return self._event


class ServerSessionStateMachine(WaypointState):
    """Waypoints for setting session mode over a protocol."""

    def __init__(self):
        WaypointState.__init__(self, {
            "ready": ("start",),
            "start": ("finish", "done"),
            "done": ("finish",),
            "finish": ("accomplished",),
            "accomplished": tuple(),
        })
        self._state = "ready"


class ProtocolSession:
    """Session that run within a protocol handler with states."""

    def __init__(self, type: int, states: dict, server: bool):
        self._type = type
        self._own_machine = ServerSessionStateMachine() if server else ClientSessionStateMachine()
        self._states = states
        self._state_machines = {
            state: ServerStateExchangeMachine() if server else ClientStateExchangeMachine()
            for state in self.states.keys()
        }

    @property
    def type(self) -> int:
        """Expose session type."""
        return self._type

    @property
    def own(self) -> WaypointState:
        """Expose the sessions states."""
        return self._own_machine

    @property
    def states(self) -> dict:
        """Expose the sessions states."""
        return self._states

    @property
    def state_machines(self) -> dict:
        """Expose the sessions states."""
        return self._state_machines


class Handler:
    """Base handler of protocol source of services."""

    LEVEL = 0
    RANGE = 0
    PACKETS = dict()
    PROCESS = dict()

    def __init__(self, manager: "Protocol"):
        self._pkt_type = None
        self._future = None
        self._silent = False

        self._manager = manager
        self._types = set(self.PACKETS.keys())

        # Enforce handling of unknown response
        unknown = r(self.RANGE)[0] + UNKNOWN_PACKET
        self.PACKETS[unknown] = UnknownPacket
        self.PROCESS[unknown] = "process_unknown"

        # Enforce handling of error response
        error = r(self.RANGE)[0] + ERROR_PACKET
        self.PACKETS[error] = ErrorPacket
        self.PROCESS[error] = "process_error"

    @property
    def manager(self) -> "Protocol":
        """Expose the packet manager."""
        return self._manager

    @property
    def current(self) -> asyncio.Future:
        """Expose current future."""
        return self._future

    def _crash(self, future: asyncio.Future) -> bool:
        """Dealing with a crash within a packet process method."""
        code = False
        try:
            future.result()
            code = True
        except CancelledError:
            if not self._silent:
                self._manager.error(ErrorCode.ABORTED, self._pkt_type, self.LEVEL)
        except InvalidStateError:
            if not self._silent:
                self._manager.error(ErrorCode.BUSY, self._pkt_type, self.LEVEL)
        except Exception as exc:
            Util.print_exception(exc)
            if not self._silent:
                self._manager.error(ErrorCode.UNEXPECTED, self._pkt_type, self.LEVEL)
        finally:
            self._cleanup(code)
            self._pkt_type = None
            self._future = None
            self._silent = False

        return code

    def _cleanup(self, ok: bool):
        """Clean up after packet processing."""
        pass

    def handle_packet(self, pkt_type: int, data: bytes):
        """Handle received packet.

        If packet type class, method or processor isn't found
        An unknown packet is returned to the senders handler.
        """
        try:
            pkt_cls = self.PACKETS[pkt_type]
            proc_name = self.PROCESS[pkt_type]
            print(pkt_type, proc_name)

            if proc_name in ("process_unknown", "process_error"):
                self._silent = True  # Don't send error or unknown response packet.

            if self._future:  # If already processing a packet.
                if not self._silent:
                    self._manager.error(ErrorCode.BUSY, pkt_type, self.LEVEL)
                return

            proc_func = getattr(self, proc_name)
            packet = pkt_cls.unpack(data)
        except (KeyError, AttributeError):
            self._manager.unknown(pkt_type, self.LEVEL)
        except (ValueError, TypeError):
            self._manager.error(ErrorCode.MALFORMED, pkt_type, self.LEVEL)
        else:
            self._pkt_type = pkt_type
            self._future = asyncio.ensure_future(proc_func(packet))
            self._future.add_done_callback(self._crash)

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


class Protocol(asyncio.Protocol):
    """Protocol for handling packages going from and to packet handlers."""

    def __init__(self, facade: Facade, server: bool = False, manager: "ConnectionManager" = None):
        self._server = server
        self._handlers = dict()
        self._ranges_available = set()
        self._ranges = dict()
        self._facade = facade
        self._manager = manager
        self._transport = None
        self._portfolio = None
        self._node = None

    @property
    def facade(self) -> Facade:
        """Expose the facade."""
        return self._facade

    @property
    def portfolio(self) -> Portfolio:
        """Expose connecting portfolio."""
        return self._portfolio

    @property
    def manager(self) -> "ConnectionManager":
        """Expose the connection manager."""
        return self._mananger

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

    def authentication_made(self, portfolio: Portfolio, node: Union[bool, Node]):
        """Indicate that authentication has taken place. Never call from outside, internal use only."""
        self._portfolio = portfolio
        self._node = node

    def connection_made(self, transport: asyncio.Transport):
        """Connection is made."""
        self._transport = transport

    def data_received(self, data: bytes):
        """Data received."""
        pkt_type = 0
        pkt_level = 0

        try:
            if len(data) <= 6:
                raise ValueError()

            pkt_type = int.from_bytes(data[0:2], "big")
            pkt_length = int.from_bytes(data[2:5], "big")
            pkt_level = int(data[5])

            if pkt_length != len(data):
                raise ValueError()

            pkt_range = ri(pkt_type)
            handler = self._ranges[pkt_range]
        except KeyError:
            low = r(pkt_range)[0]
            if pkt_type == low + UNKNOWN_PACKET or pkt_type == low + ERROR_PACKET:
                pass  # Attempted attack
            else:
                self.unknown(pkt_type, pkt_level)
        except (ValueError, struct.error):
            self.error(ErrorCode.MALFORMED, pkt_type, pkt_level)
        else:
            handler.handle_packet(pkt_type, data[6:])

    def send_packet(self, pkt_type: int, pkt_level: int, packet: Packet):
        """Send packet over socket."""
        if not self._transport:
            raise NetworkError(*NetworkError.NO_TRANSPORT)

        data = bytes(packet)
        self._transport.write(
            pkt_type.to_bytes(2, "big") +
            (6 + len(data)).to_bytes(3, "big") +
            pkt_level.to_bytes(1, "big") +
            data
        )

    def unknown(self, pkt_type: int, pkt_level: int, process: int = 0):
        """Unknown packet is returned to sender."""
        self.send_packet(
            r(pkt_type)[0] + UNKNOWN_PACKET, pkt_level,
            UnknownPacket(pkt_type, pkt_level, process)
        )

    def error(self, error: int, pkt_type: int, pkt_level, process: int = 0):
        """Error happened is returned to sender."""
        self.send_packet(
            r(pkt_type)[0] + ERROR_PACKET, pkt_level,
            ErrorPacket(pkt_type, pkt_level, process, error)
        )


class ClientProtoMixin:
    """Client of packet manager."""

    def connection_lost(self, exc: Exception):
        """Clean up."""
        if exc:
            Util.print_exception(exc)
        self._transport.close()

    @classmethod
    async def connect(cls, facade: Facade, host: Union[str, IPv4Address, IPv6Address], port: int) -> "Protocol":
        """Connect to server."""
        _, protocol = await asyncio.get_running_loop().create_connection(
            lambda: cls(facade), str(host), port)
        return protocol


class ServerProtoMixin:
    """Server of packet manager."""

    def eof_received(self):
        """End of communication."""
        if self._manager:
            self._manager.remove(self)

    def connection_lost(self, exc: Exception):
        """Clean up."""
        if self._manager:
            self._manager.remove(self)
        Util.print_exception(exc)

    def connection_made(self, transport: asyncio.Transport):
        """Add serving protocol to local dict and set."""
        Protocol.connection_made(self, transport)
        if self._manager:
            self._manager.add(self)

    @classmethod
    async def listen(
            cls, facade: Facade, host: Union[str, IPv4Address, IPv6Address],
            port: int, manager: "ConnectionManager" = None
    ) -> asyncio.base_events.Server:
        """Start a listening server."""
        return await asyncio.get_running_loop().create_server(lambda: cls(facade, manager), host, port)


class ConnectionManager:
    """Keeps track at connections with server protocols."""

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
