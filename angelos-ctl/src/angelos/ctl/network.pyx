# cython: language_level=3, linetrace=True
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Administration client."""
from typing import Awaitable

from angelos.facade.facade import Facade
from angelos.net.authentication import AuthenticationClient, AuthenticationHandler
from angelos.net.base import Protocol, ClientProtoMixin
from angelos.net.broker import ServiceBrokerClient
from angelos.net.tty import TTYHandler, TTYClient


class AuthenticationFailure(RuntimeWarning):
    """Authentication failed for some reason."""
    pass


class ServiceNotAvailable(RuntimeWarning):
    """Service is not available on the other side."""


class ClientAdmin(Protocol, ClientProtoMixin):
    """Administrator admin client."""

    def __init__(self, facade: Facade, emergency: Awaitable = None):
        super().__init__(facade, emergency=emergency)
        self._add_handler(ServiceBrokerClient(self))
        self._add_handler(AuthenticationClient(self))

    async def authenticate(self):
        """Authenticate on server as admin."""
        success = await self.get_handler(AuthenticationHandler.RANGE).auth_admin()
        if not success:
            raise AuthenticationFailure("Authenticating as admin user failed.")
        self._add_handler(TTYClient(self))

    async def open(self, cols=80, lines=24):
        """Open pseudo-terminal at server."""
        success = await self.get_handler(ServiceBrokerClient.RANGE).request(TTYHandler.RANGE)
        if not success:
            raise ServiceNotAvailable("TTY handler not available at server.")

        return await self.get_handler(TTYHandler.RANGE).pty(max(80, min(240, cols)), max(8, min(72, lines)))

    def connection_lost(self, exc: Exception):
        super().connection_lost(exc)