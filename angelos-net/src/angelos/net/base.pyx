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
import time
import uuid
from typing import Tuple, NamedTuple, Union, Any

import msgpack
from angelos.document.domain import Node
from angelos.facade.facade import Facade
from angelos.portfolio.collection import Portfolio

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


# 1. Packet type, 2 bytes
# 2. Packet length, 3 bytes
# 3. Packet management level, 1 byte
# Packet management levels:
# 1. Session handler
# 2. Service
# 3. Sub service
from msgpack import ExtType

UNKNOWN_TYPE = 126
ERROR_TYPE = 127


class ErrorCode(enum.Enum):
    """Error codes"""
    MALFORMED = 1


class NetworkError(RuntimeWarning):
    PACKET_SIZE_MISMATCH = ("Received packet not of announced size.", 100)
    AUTH_ALREADY_DONE = ("Authentication already done.", 101)
    AUTH_TIMEGATE_DIFF = ("Authentication time difference to large.", 102)


def r(i: int) -> Tuple[int, int]:
    """Interval boundaries for given range."""
    return (i - 1) * 128, i * 128 - 1


def ri(n: int) -> int:
    """Range for given number."""
    return n // 128 + 1


UINT_DATATYPE = 0x01
UUID_DATATYPE = 0x02
BYTES_FIX_DATATYPE = 0x03
BYTES_VAR_DATATYPE = 0x04
DATETIME_DATATYPE = 0x05


def default(obj: Any) -> msgpack.ExtType:
    """Custom message pack type converter."""
    if isinstance(obj, int):
        return ExtType(UINT_DATATYPE, obj.to_bytes(8, "big", signed=False))
    elif isinstance(obj, uuid.UUID):
        return ExtType(UUID_DATATYPE, obj.bytes)
    elif isinstance(obj, memoryview):
        return ExtType(BYTES_FIX_DATATYPE, obj)
    elif isinstance(obj, bytes):
        return ExtType(BYTES_VAR_DATATYPE, obj)
    elif isinstance(obj, datetime.datetime):
        return ExtType(DATETIME_DATATYPE, int(
            datetime.datetime.utcfromtimestamp(
                obj.timestamp()).timestamp()).to_bytes(8, "big", signed=False))
    else:
        raise TypeError("Unsupported: {}".format(type(obj)))


def ext_hook(code: int, data: bytes) -> Any:
    """Custom message unpack type converter."""
    if code == UINT_DATATYPE:
        return int.from_bytes(data, "big", signed=False)
    elif code == UUID_DATATYPE:
        return uuid.UUID(bytes=data)
    elif code == BYTES_FIX_DATATYPE:
        return data
    elif code == BYTES_VAR_DATATYPE:
        return data
    elif code == DATETIME_DATATYPE:
        return datetime.datetime.fromtimestamp(
            int.from_bytes(data, "big", signed=False)).replace(
                tzinfo=datetime.timezone.utc).astimezone()
    return ExtType(code, data)

datetime.datetime.utcfromtimestamp(234234234)


class PacketMeta(type):
    """Meta class for packets so that they work almost like named tuples."""

    def __new__(mcs, name: str, bases: tuple, namespace: dict):
        """Scan through the fields and hide the meta data."""
        print(name)
        fields = list()

        ns = namespace.copy()
        for name, field in namespace.items():
            if isinstance(field, tuple):
                print(name)
                fields.append((name,) + field)
                if field[0] == BYTES_FIX_DATATYPE:
                    _name = "_" + name
                    ns[_name] = bytes(field[1])
                    ns[name] = memoryview(ns[_name]).cast("B")
                else:
                    ns[name] = None

        ns["_glorx"] = tuple(fields)

        return super().__new__(mcs, name, bases, ns)


class Packet(metaclass=PacketMeta):
    """Network packet base class.

    Example:

    class MyPacket(Packet):
        uint = (UINT_DATATYPE, 100, 200)  # <-- min and max are optional
        uuid = (UUID_DATATYPE,)
        fixed = (BYTES_FIX_DATATYPE, 128)  # <-- size is mandatory
        variable = (BYTES_VAR_DATATYPE, 50, 200)  # <-- min and max are optional
    """

    def __init__(self, data: bytes = None):
        if not data:
            return

        for index, value in enumerate(msgpack.unpackb(data, ext_hook=ext_hook, raw=False)):
            meta = self._glorx[index]
            attr = meta[0]
            code = meta[1]

            if code == UINT_DATATYPE:
                if len(meta) == 4:
                    if not (meta[2] <= value <= meta[3]):
                        raise ValueError("Value not within {0}~{1}: was {2}".format(meta[2], meta[3], value))
                setattr(self, attr, value)

            elif code == UUID_DATATYPE:
                setattr(self, attr, value)

            elif code == BYTES_FIX_DATATYPE:
                size = meta[2]
                if len(value) != size:
                    raise ValueError("Wrong size on '{0}': was {1}, expected {2}".format(attr, size, len(value)))
                view = getattr(self, attr)
                view[0:size] = value[0:size]

            elif code == BYTES_VAR_DATATYPE:
                if len(meta) == 4:
                    size = len(value)
                    if not (meta[2] <= size <= meta[3]):
                        raise ValueError("Size not within {0}~{1}: was {2}".format(meta[2], meta[3], size))
                setattr(self, attr, value)

            elif code == DATETIME_DATATYPE:
                setattr(self, attr, value)

            else:
                raise TypeError("Type not implemented: code {}".foramt(meta[1]))

    def __bytes__(self) -> bytes:
        return msgpack.packb(tuple([
            getattr(self, meta[0]) for meta in self._glorx]), default=default, use_bin_type=True)


class ErrorPacket(NamedTuple("ErrorPacket", [("type", int), ("level", int), ("process", int), ("error", int)])):
    """"""
    pass


class UnknownPacket(NamedTuple("UnknownPacket", [("type", int), ("level", int), ("process", int)])):
    """"""
    pass


class PacketHandler:
    """Base handler of protocol source of services."""

    LEVEL = 0
    RANGE = 0
    PACKETS = dict()
    PROCESS = dict()

    def __init__(self, manager: "PacketManager"):
        self._manager = manager
        self._types = set(self.PACKETS.keys())

        # Enforce handling of unknown response
        unknown = r(self.RANGE)[0] + UNKNOWN_TYPE
        self.PACKETS[unknown] = UnknownPacket
        self.PROCESS[unknown] = "process_unknown"

        # Enforce handling of error response
        error = r(self.RANGE)[0] + ERROR_TYPE
        self.PACKETS[error] = ErrorPacket
        self.PROCESS[error] = "process_error"

    @property
    def manager(self) -> "PacketManager":
        """Expose the packet manager."""
        return self._manager

    def handle_packet(self, pkt_type: int, data: bytes):
        """Handle received packet.

        If packet type class, method or processor isn't found
        An unknown packet is returned to the senders handler.
        """
        try:
            pkt_cls = self.PACKETS[pkt_type]
            proc_func = getattr(self, self.PROCESS[pkt_type])
        except (KeyError, AttributeError):
            self._manager.unknown(pkt_type, self.LEVEL)
        else:
            asyncio.run_coroutine_threadsafe(proc_func(pkt_cls(*msgpack.unpackb(data))))

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


class PacketManager(asyncio.Protocol):
    """Protocol for handling packages going from and to packet handlers."""

    PKT_HELLO = struct.Struct("!")  # Synchronize greeting
    PKT_FINISH = struct.Struct("!")  # Hang up on connection

    def __init__(self, facade: Facade):
        self._services = dict()
        self._range_to_service = dict()
        self._facade = facade
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

    def _add_service(self, service: PacketHandler):
        if service.LEVEL not in self._services.keys():
            self._services[service.LEVEL] = set()
        level = self._services[service.LEVEL]
        level.add(service)

        self._ranges.add(service.RANGE)
        self._range_to_service[service.RANGE] = service

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

            pkt_type = data[0:1].to_bytes(2, "big")
            pkt_length = data[2:4].from_bytes(3, "big")
            pkt_level = data[5].from_bytes(1, "big")

            if pkt_length != len(data):
                raise ValueError()

            pkt_range = ri(pkt_type)
            handler = self._ranges[pkt_range]
        except KeyError:
            low, _ = r(pkt_range)
            if pkt_type == low + UNKNOWN_TYPE or pkt_type == low + ERROR_TYPE:
                pass  # Attempted attack
            else:
                self.unknown(pkt_type, pkt_level)
        except (ValueError, struct.error):
            self.error(ErrorCode.MALFORMED, pkt_type, pkt_level)
        else:
            handler.handle_packet(pkt_type, data[6:])

    def send_packet(self, pkt_type: int, pkt_level: int, data: bytes):
        """Send packet over socket."""
        self._transport.write(
            bytes.to_bytes(pkt_type, "big", 2) +
            (6 + len(data)).to_bytes(3, "big") +
            bytes.to_bytes(pkt_level, "big", 1) +
            data
        )

    def serialize(self, packet: NamedTuple) -> bytes:
        """Pack the named tuple with messagepack."""
        return msgpack.packb(packet._asdict())

    def unknown(self, pkt_type: int, pkt_level, process: int = 0):
        """Unknown packet is returned to sender."""
        packet = UnknownPacket(pkt_type, pkt_level, process)
        low, _ = ri(pkt_type)
        self.send_packet(low + UNKNOWN_TYPE, pkt_level, self.serialize(packet))

    def error(self, error: int, pkt_type: int, pkt_level, process: int = 0):
        """Error happened is returned to sender."""
        packet = ErrorPacket(pkt_type, pkt_level, process, error)
        low, _ = ri(pkt_type)
        self.send_packet(low + ERROR_TYPE, pkt_level, self.serialize(packet))
