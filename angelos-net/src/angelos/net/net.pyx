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
"""Network client and server classes to connect and listen."""
import asyncio

from angelos.facade.facade import Facade
from angelos.net.authentication import AuthenticationServer, AuthenticationClient
from angelos.net.base import Protocol, ClientProtoMixin, ServerProtoMixin, ConnectionManager
from angelos.net.broker import ServiceBrokerClient, ServiceBrokerServer


class Client(Protocol, ClientProtoMixin):
    """Client of packet manager."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(ServiceBrokerClient(self))
        self._add_handler(AuthenticationClient(self))


class Server(Protocol, ServerProtoMixin):
    """Server of packet manager."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(ServiceBrokerServer(self))
        self._add_handler(AuthenticationServer(self))

    def connection_made(self, transport: asyncio.Transport):
        """Add more handlers according to authentication."""
        ServerProtoMixin.connection_made(self, transport)
