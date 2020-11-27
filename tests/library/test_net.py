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
import asyncio
import struct
import time
import uuid
from ipaddress import IPv4Address, IPv6Address
from typing import NamedTuple, Union, Tuple
from unittest import TestCase

import msgpack
from angelos.bin.nacl import Signer, NaCl, Verifier, CryptoFailure
from angelos.document.domain import Node
from angelos.facade.facade import Facade
from angelos.facade.storage.portfolio_mixin import PortfolioNotFound
from angelos.lib.policy.crypto import Crypto
from angelos.meta.testing import run_async
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.utils import Groups


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


# 1. Packet type, 2 bytes
# 2. Packet length, 3 bytes
# 3. Packet management level, 1 byte
# Packet management levels:
# 1. Session handler
# 2. Service
# 3. Sub service


class NetworkError(RuntimeWarning):
    PACKET_SIZE_MISMATCH = ("Received packet not of announced size.", 100)
    AUTH_ALREADY_DONE = ("Authentication already done.", 101)
    AUTH_TIMEGATE_DIFF = ("Authentication time difference to large.", 102)


class AuthenticationRequestPacket(NamedTuple):
    id: bytes           # Client ID
    key: bytes          # Public key
    specimen: bytes     # Specimen data
    signature: bytes    # Signature of specimen data using public key


class AuthenticationSuccessPacket(NamedTuple):
    id: bytes           # Server ID
    key: bytes          # Public key
    specimen: bytes     # Specimen data
    signature: bytes    # Signature of specimen data using public key


class AuthenticationFailurePacket(NamedTuple):
    reason: int         # Reason of failure


class Handler:
    """Base handler of protocol source of services."""

    LEVEL = 0
    RANGE = 0
    PACKETS = {}

    def __init__(self, manager: "PacketManager"):
        self._manager = manager

    @property
    def manager(self) -> "PacketManager":
        """Expose the packet manager."""
        return self._manager

    def pack(self, packet: NamedTuple) -> bytes:
        """Pack the named tuple with messagepack."""
        return msgpack.packb(packet._asdict())

    async def handle_packet(self, pkt_type: int, data: bytes):
        """Handle received packet."""
        pkt_cls, processor = self.PACKETS[pkt_type]
        await getattr(self, processor)(pkt_cls(*msgpack.unpackb(data)))


class AuthenticationClient(Handler):
    """Handles user negotiation and authentication"""

    LEVEL = 1
    RANGE = 1
    PACKETS = {
        5: (AuthenticationRequestPacket, None),
        6: (AuthenticationSuccessPacket, "process_success"),
        7: (AuthenticationFailurePacket, "process_failure"),
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager)

    def start(self, node: bool = False):
        """Make authentication against server."""
        portfolio = self.manager.facade.data.portfolio
        keys = Crypto.latest_keys(portfolio.keys)
        specimen = self.build_specimen(node)
        pkt_cls, _ = self.PACKETS[5]
        packet = pkt_cls(
            portfolio.entity.id, keys.verify, specimen, Signer(portfolio.privkeys.seed).signature(specimen))
        self._manager.send_packet(5, self.LEVEL, self.pack(packet))

    def build_specimen(self, node: bool) -> bytes:
        specimen = self._manager.facade.data.portfolio.node.id.bytes if node else NaCl.random_bytes(16)
        specimen += int(time.time()).to_bytes(8, "big") + NaCl.random_bytes(40)
        return specimen

    async def process_success(self, packet: AuthenticationSuccessPacket):
        pass

    async def process_failure(self, packet, AuthenticationFailurePacket):
        pass


class AuthenticationServer(Handler):
    """Handles user negotiation and authentication"""

    LEVEL = 1
    RANGE = 1
    PACKETS = {
        5: (AuthenticationRequestPacket, "process_request"),
        6: (AuthenticationSuccessPacket, None),
        7: (AuthenticationFailurePacket, None),
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager)
        self._done = False

    def build_specimen(self, node: bool) -> bytes:
        specimen = self._manager.facade.data.portfolio.node.id.bytes if node else NaCl.random_bytes(16)
        specimen += int(time.time()).to_bytes(8, "big") + NaCl.random_bytes(40)
        return specimen

    def chop_specimen(self, specimen: bytes) -> Tuple[uuid.UUID, int, bytes]:
        return tuple(
            uuid.UUID(bytes=specimen[:16]),
            int.from_bytes(specimen[17:24], "big"),
            specimen[25:]
        )

    async def process_request(self, packet: AuthenticationRequestPacket):
        """Process incoming authentication request."""
        try:
            if self._done:  # Has authentication already been attempted
                raise NetworkError(*NetworkError.AUTH_ALREADY_DONE)
            self._done = True

            identity = uuid.UUID(bytes=packet.id)
            specimen = self.chop_specimen(packet.specimen)

            if abs(specimen[1] - time.time()) > 240:
                raise NetworkError(*NetworkError.AUTH_TIMEGATE_DIFF)

            portfolio = self.manager.facade.storage.vault.load_portfolio(identity, Groups.CLIENT_AUTH)

            if self._manager.facade.data.portfolio.entity.id == identity:  # Check node privileges
                keys = [keys for keys in self._manager.facade.data.portfolio.keys if keys.verify == packet.key][0]
                node = [node for node in self._manager.facade.data.portfolio.node if node.id == specimen[0]][0]
            else:  # Check normal logon
                keys = [keys for keys in portfolio.keys if keys.verify == packet.key][0]
                node = False

            Verifier(keys.verify).verify(packet.signature + packet.specimen)
            self._manager.authentication_made(portfolio, node)
        except ValueError:  # Malformed or illegal data
            self._manager.send_packet(7, self.LEVEL, self.PACKETS[7][0](1))
        except PortfolioNotFound:  # Unknown identity
            self._manager.send_packet(7, self.LEVEL, self.PACKETS[7][0](2))
        except IndexError:  # Unknown key or node
            self._manager.send_packet(7, self.LEVEL, self.PACKETS[7][0](3))
        except CryptoFailure:  # Verification failed
            self._manager.send_packet(7, self.LEVEL, self.PACKETS[7][0](4))
        except NetworkError:  # Authentication already done
            self._manager.send_packet(7, self.LEVEL, self.PACKETS[7][0](5))
        else:  # Success
            portfolio = self.manager.facade.data.portfolio
            keys = Crypto.latest_keys(portfolio.keys)
            pkt_cls, _ = self.PACKETS[6]
            packet = pkt_cls(
                portfolio.entity.id, keys.verify, self.build_specimen(bool(node)),
                Signer(portfolio.privkeys.seed).signature(specimen)
            )
            self._manager.send_packet(6, self.LEVEL, self.pack(packet))


class ServiceBrokerHandler(Handler):
    """Brokes the available services to use."""

    LEVEL = 2
    PACKETS = {}


class PacketManager(asyncio.Protocol):
    PKT_READER = struct.Struct("!Hc3B")
    PKT_HELLO = struct.Struct("!")  # Synchronize greeting
    PKT_FINISH = struct.Struct("!")  # Hang up on connection
    PKT_UNKNOWN = struct.Struct("!")

    def __init__(self, facade: Facade):
        self._facade = facade
        self._transport = None
        self._services = None
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

    def authentication_made(self, portfolio: Portfolio, node: Union[bool, Node]):
        """Indicate that authentication has taken place. Never call from outside, internal use only."""
        self._portfolio = portfolio
        self._node = node

    def connection_made(self, transport: asyncio.Transport):
        """Connection is made."""
        self._transport = transport

    def data_received(self, data: bytes):
        """Data received."""
        pkt_type, length_data, pkt_level = self.PKT_READER.unpack_from(data, 0)
        pkt_length = int.from_bytes(length_data, "big")
        if pkt_length != len(data):
            raise NetworkError(*NetworkError.PACKET_SIZE_MISMATCH)
        pkt_range = pkt_type // 128 + 1

    def send_packet(self, pkt_type: int, pkt_level, data: bytes):
        """Send packet over socket."""
        pkt_length = (self.PKT_READER.size + len(data)).to_bytes(3, "big")
        self._transport.write(self.PKT_READER.pack(pkt_type, pkt_length, pkt_level) + data)


class Client(PacketManager):
    """Client of packet manager."""

    SERVER = (False, )

    def connection_lost(self, exc: Exception):
        """Clean up."""

        print('Client: The server closed the connection', exc)
        self._transport.close()

    @classmethod
    async def connect(cls, facade: Facade, host: Union[str, IPv4Address, IPv6Address], port: int) -> "Client":
        """Connect to server."""
        _, protocol = await asyncio.get_running_loop().create_connection(
            lambda: cls(facade), str(host), port)
        return protocol


class Server(PacketManager):
    """Server of packet manager."""

    SERVER = (True, )

    @classmethod
    async def listen(
            cls, facade: Facade,
            host: Union[str, IPv4Address, IPv6Address], port: int
    ) -> asyncio.base_events.Server:
        """Start a listening server."""
        return await asyncio.get_running_loop().create_server(lambda: cls(facade), host, port)


class NetworkTest(TestCase):

    @run_async
    async def test_run(self):
        server = await Server.listen(None, "127.0.0.1", 8000)
        server_task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)
        client = await Client.connect(None, "127.0.0.1", 8000)


