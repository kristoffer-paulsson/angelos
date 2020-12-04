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
"""Authentication handler."""
import time
import uuid
from typing import NamedTuple, Tuple

from angelos.bin.nacl import NaCl, Signer, Verifier, CryptoFailure
from angelos.facade.storage.portfolio_mixin import PortfolioNotFound
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.utils import Groups

from angelos.net.base import NetworkError, PacketHandler


class AuthenticationError(RuntimeWarning):
    AUTH_ALREADY_DONE = ("Authentication already done.", 100)
    AUTH_TIMEGATE_DIFF = ("Authentication time difference to large.", 101)


class AuthenticationRequestPacket(NamedTuple):
    """Authentication request packet data tuple."""
    id: bytes  # Client ID
    key: bytes  # Public key
    specimen: bytes  # Specimen data
    signature: bytes  # Signature of specimen data using public key


class AuthenticationSuccessPacket(NamedTuple):
    """Authentication success packet data tuple."""
    id: bytes  # Server ID
    key: bytes  # Public key
    specimen: bytes  # Specimen data
    signature: bytes  # Signature of specimen data using public key


class AuthenticationFailurePacket(NamedTuple):
    """Authentication failure packet data tuple."""
    reason: int  # Reason of failure


class AuthenticationHandler(PacketHandler):
    """Base handler for authentication."""

    LEVEL = 1
    RANGE = 1

    PKT_REQUEST = 5
    PKT_SUCCESS = 6
    PKT_FAILURE = 7

    PACKETS = {
        PKT_REQUEST: AuthenticationRequestPacket,
        PKT_SUCCESS: AuthenticationSuccessPacket,
        PKT_FAILURE: AuthenticationFailurePacket
    }

    PROCESS = dict()

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


class AuthenticationClient(AuthenticationHandler):
    """Handles user negotiation and authentication"""

    PROCESS = {
        AuthenticationHandler.PKT_REQUEST: None,
        AuthenticationHandler.PKT_SUCCESS: "process_success",
        AuthenticationHandler.PKT_FAILURE: "process_failure",
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager)

    def start(self, node: bool = False):
        """Make authentication against server."""
        portfolio = self.manager.facade.data.portfolio
        keys = Crypto.latest_keys(portfolio.keys)
        specimen = self.build_specimen(node)
        pkt_cls, _ = self.PACKETS[self.PKT_REQUEST]
        packet = pkt_cls(
            portfolio.entity.id, keys.verify, specimen, Signer(portfolio.privkeys.seed).signature(specimen))
        self._manager.send_packet(self.PKT_REQUEST, self.LEVEL, self.pack(packet))

    async def process_success(self, packet: AuthenticationSuccessPacket):
        pass

    async def process_failure(self, packet, AuthenticationFailurePacket):
        pass


class AuthenticationServer(AuthenticationHandler):
    """Handles user negotiation and authentication"""

    PROCESS = {
        AuthenticationHandler.PKT_REQUEST: "process_request",
        AuthenticationHandler.PKT_SUCCESS: None,
        AuthenticationHandler.PKT_FAILURE: None
    }

    def __init__(self, manager: "PacketManager"):
        super().__init__(manager)
        self._done = False

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
            self._manager.send_packet(self.PKT_FAILURE, self.LEVEL, self.PACKETS[self.PKT_FAILURE](1))
        except PortfolioNotFound:  # Unknown identity
            self._manager.send_packet(self.PKT_FAILURE, self.LEVEL, self.PACKETS[self.PKT_FAILURE](2))
        except IndexError:  # Unknown key or node
            self._manager.send_packet(self.PKT_FAILURE, self.LEVEL, self.PACKETS[self.PKT_FAILURE](3))
        except CryptoFailure:  # Verification failed
            self._manager.send_packet(self.PKT_FAILURE, self.LEVEL, self.PACKETS[self.PKT_FAILURE](4))
        except NetworkError:  # Authentication already done
            self._manager.send_packet(self.PKT_FAILURE, self.LEVEL, self.PACKETS[self.PKT_FAILURE](5))
        else:  # Success
            portfolio = self.manager.facade.data.portfolio
            keys = Crypto.latest_keys(portfolio.keys)
            pkt_cls, _ = self.PACKETS[self.PKT_SUCCESS]
            packet = pkt_cls(
                portfolio.entity.id, keys.verify, self.build_specimen(bool(node)),
                Signer(portfolio.privkeys.seed).signature(specimen)
            )
            self._manager.send_packet(self.PKT_SUCCESS, self.LEVEL, self.pack(packet))