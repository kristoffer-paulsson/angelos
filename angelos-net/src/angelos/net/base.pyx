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
import enum
import struct
from typing import Tuple, NamedTuple, Union

import msgpack
from angelos.document.domain import Node
from angelos.facade.facade import Facade
from angelos.portfolio.collection import Portfolio


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


class ErrorPacket(NamedTuple):
    """Return error to sending handler. (127)"""
    type: int
    level: int
    process: int
    error: int


class UnknownPacket(NamedTuple):
    """Return unknown packet type to sending handler. (126)"""
    type: int
    level: int
    process: int


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
        unknown = r(self.RANGE) + UNKNOWN_TYPE
        self.PACKETS[unknown] = UnknownPacket
        self.PROCESS[unknown] = "process_unknown"

        # Enforce handling of error response
        error = r(self.RANGE) + ERROR_TYPE
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
    HEADER = struct.Struct("!H3sB")

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

            pkt_type, length_data, pkt_level = self.HEADER.unpack_from(data, 0)
            pkt_length = int.from_bytes(length_data, "big")

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
            handler.handle_packet(pkt_type, data[self.HEADER.size:])

    def send_packet(self, pkt_type: int, pkt_level: int, data: bytes):
        """Send packet over socket."""
        pkt_length = (self.HEADER.size + len(data)).to_bytes(3, "big")
        self._transport.write(self.HEADER.pack(pkt_type, pkt_length, pkt_level) + data)

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
