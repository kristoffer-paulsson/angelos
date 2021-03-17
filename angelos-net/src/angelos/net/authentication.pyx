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
import asyncio
import time
import uuid

from angelos.bin.nacl import NaCl, Signer, Verifier, CryptoFailure
from angelos.common.misc import AsyncCallable, SyncCallable
from angelos.common.utils import Util
from angelos.facade.storage.portfolio_mixin import PortfolioNotFound
from angelos.lib.policy.crypto import Crypto
from angelos.net.base import NetworkError, Handler, ConfirmCode, StateMode, ProtocolNegotiationError, NetworkSession
from angelos.portfolio.utils import Groups

AUTHENTICATION_VERSION = b"authentication-0.1"


class LoginTypeCode:
    LOGIN_USER = bytes([0x01])  # User logon to network
    LOGIN_NODE = bytes([0x02])  # Node within same domain logon
    LOGIN_NET = bytes([0x03])  # Another network logon
    LOGIN_ADMIN = bytes([0x04])  # Admin public key logon


class AuthenticationHandler(Handler):

    LEVEL = 1
    RANGE = 1

    ST_VERSION = 0x01
    ST_LOGIN = 0x02

    ST_SERVER_ID = 0x03
    ST_SERVER_PUBLIC = 0x04
    ST_SERVER_SPECIMEN = 0x05
    ST_SERVER_SIGNATURE = 0x06
    ST_SERVER_TIME = 0x07

    ST_CLIENT_ID = 0x08
    ST_CLIENT_NODE = 0x09
    ST_CLIENT_PUBLIC = 0x0A
    ST_CLIENT_SPECIMEN = 0x0B
    ST_CLIENT_SIGNATURE = 0x0C
    ST_CLIENT_TIME = 0x0D

    def __init__(self, manager: "Protocol"):
        portfolio = manager.facade.data.portfolio
        keys = Crypto.latest_keys(portfolio.keys)
        specimen = NaCl.random_bytes(64)
        server = manager.is_server()
        Handler.__init__(self, manager, states={
            self.ST_VERSION: (StateMode.MEDIATE, AUTHENTICATION_VERSION),
            self.ST_LOGIN: (StateMode.ONCE, b""),
            self.ST_SERVER_ID: (StateMode.FACT, portfolio.entity.id.bytes if server else uuid.UUID(int=0).bytes),
            self.ST_SERVER_PUBLIC: (StateMode.FACT, keys.verify if server else b""),
            self.ST_SERVER_SPECIMEN: (StateMode.FACT, specimen if server else b""),
            self.ST_SERVER_SIGNATURE: (StateMode.ONCE, b""),
            self.ST_SERVER_TIME: (StateMode.FACT, int(time.time()).to_bytes(8, "big") if server else b""),
            self.ST_CLIENT_ID: (StateMode.ONCE, uuid.UUID(int=0).bytes if server else portfolio.entity.id.bytes),
            self.ST_CLIENT_NODE: (StateMode.ONCE, b""),
            self.ST_CLIENT_PUBLIC: (StateMode.ONCE, b"" if server else keys.verify),
            self.ST_CLIENT_SPECIMEN: (StateMode.ONCE, b"" if server else specimen),
            self.ST_CLIENT_SIGNATURE: (StateMode.FACT, b""),
            self.ST_CLIENT_TIME: (StateMode.ONCE, b"" if server else int(time.time()).to_bytes(8, "big")),
        })


class AuthenticationClient(AuthenticationHandler):

    def __init__(self, manager: "Protocol"):
        AuthenticationHandler.__init__(self, manager)

    async def _login(self, node: bool = False) -> bool:
        """Login operation against server."""
        version = await self._call_mediate(self.ST_VERSION, [AUTHENTICATION_VERSION])
        if version is None:
            raise ProtocolNegotiationError()

        await self._call_tell(self.ST_LOGIN)
        if node:
            await self._call_tell(self.ST_CLIENT_NODE)

        await self._call_query(self.ST_SERVER_ID)
        await self._call_query(self.ST_SERVER_PUBLIC)
        await self._call_query(self.ST_SERVER_SPECIMEN)
        await self._call_query(self.ST_SERVER_TIME)

        await self._call_tell(self.ST_CLIENT_ID)
        await self._call_tell(self.ST_CLIENT_PUBLIC)
        await self._call_tell(self.ST_CLIENT_SPECIMEN)
        await self._call_tell(self.ST_CLIENT_TIME)

        self._states[self.ST_SERVER_SIGNATURE].update(
            Signer(self._manager.facade.data.portfolio.privkeys.seed).signature(
                self._states[self.ST_SERVER_SPECIMEN].value))

        approved = await self._call_tell(self.ST_SERVER_SIGNATURE)

        # Authentication at server failed
        if approved is None:
            return False

        await self._call_query(self.ST_CLIENT_SIGNATURE)

        try:
            identity = uuid.UUID(bytes=self._states[self.ST_SERVER_ID].value)
            portfolio = await self.manager.facade.storage.vault.load_portfolio(identity, Groups.CLIENT_AUTH)

            if self._manager.facade.data.portfolio.entity.id == identity:  # Check node privileges
                keys = [keys for keys in self._manager.facade.data.portfolio.keys if
                        keys.verify == self._states[self.ST_SERVER_PUBLIC].value][0]
                node = [node for node in self._manager.facade.data.portfolio.node if
                        node.id == uuid.UUID(bytes=self._states[self.ST_SERVER_NODE].value)][0]
            else:  # Check normal logon
                keys = [keys for keys in portfolio.keys if keys.verify == self._states[self.ST_SERVER_PUBLIC].value][0]
                node = False

            Verifier(keys.verify).verify(
                self._states[self.ST_CLIENT_SIGNATURE].value + self._states[self.ST_CLIENT_SPECIMEN].value)
            self._manager.authentication_made(portfolio, node)
            return True
        except (ValueError, IndexError, PortfolioNotFound, CryptoFailure) as exc:
            Util.print_exception(exc)
            self._manager.close()
            return False

    async def auth_user(self) -> bool:
        """Authenticate a user against a network."""
        self._states[self.ST_LOGIN].update(LoginTypeCode.LOGIN_USER)
        return await self._login()

    # TODO: Implement node authentication
    async def auth_node(self) -> bool:
        """Authenticate a node within a network."""
        self._states[self.ST_LOGIN].update(LoginTypeCode.LOGIN_NODE)

    # TODO: Implement network authentication
    async def auth_net(self) -> bool:
        """Authenticate a network against another network."""
        self._states[self.ST_LOGIN].update(LoginTypeCode.LOGIN_NET)

    # TODO: Implement administrator authentication
    async def auth_admin(self) -> bool:
        """Authenticate an administrator against server."""
        self._states[self.ST_LOGIN].update(LoginTypeCode.LOGIN_ADMIN)


class AuthenticationServer(AuthenticationHandler):

    def __init__(self, manager: "Protocol"):
        AuthenticationHandler.__init__(self, manager)
        self._states[self.ST_VERSION].upgrade(SyncCallable(self._check_version))
        self._states[self.ST_LOGIN].upgrade(SyncCallable(self._check_login))
        self._states[self.ST_SERVER_SIGNATURE].upgrade(AsyncCallable(self._check_signature))

    def _check_version(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Negotiate protocol version."""
        return ConfirmCode.YES if value == AUTHENTICATION_VERSION else ConfirmCode.NO

    def _check_login(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Check login type availability."""
        return ConfirmCode.YES if value == LoginTypeCode.LOGIN_USER else ConfirmCode.NO

    async def _check_signature(self, value: bytes, sesh: NetworkSession = None) -> int:
        """Authenticate signature."""
        self._states[self.ST_CLIENT_SIGNATURE].update(
            Signer(self._manager.facade.data.portfolio.privkeys.seed).signature(
                self._states[self.ST_CLIENT_SPECIMEN].value))

        try:
            identity = uuid.UUID(bytes=self._states[self.ST_CLIENT_ID].value)
            if abs(int.from_bytes(self._states[self.ST_CLIENT_TIME].value, "big") - time.time()) > 240:
                raise NetworkError(*NetworkError.AUTH_TIMEGATE_DIFF)

            portfolio = await self.manager.facade.storage.vault.load_portfolio(identity, Groups.CLIENT_AUTH)

            if self._manager.facade.data.portfolio.entity.id == identity:  # Check node privileges
                keys = [keys for keys in self._manager.facade.data.portfolio.keys if
                        keys.verify == self._states[self.ST_CLIENT_PUBLIC].value][0]
                node = [node for node in self._manager.facade.data.portfolio.node if
                        node.id == uuid.UUID(bytes=self._states[self.ST_CLIENT_NODE].value)][0]
            else:  # Check normal logon
                keys = [keys for keys in portfolio.keys if keys.verify == self._states[self.ST_CLIENT_PUBLIC].value][0]
                node = False

            Verifier(keys.verify).verify(value + self._states[self.ST_SERVER_SPECIMEN].value)
            self._manager.authentication_made(portfolio, node)
        except (ValueError, IndexError, PortfolioNotFound, CryptoFailure, NetworkError) as exc:
            Util.print_exception(exc)
            asyncio.get_event_loop().call_soon(self._manager.close)
            return ConfirmCode.NO
        else:
            return ConfirmCode.YES
