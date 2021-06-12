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
"""Implementation of the network for the Angelos server."""
import asyncio

from angelos.facade.facade import Facade
from angelos.lib.ioc import Container, ContainerAware
from angelos.net.authentication import AuthenticationServer, AdminAuthMixin
from angelos.net.base import Protocol, ServerProtoMixin, ConnectionManager
from angelos.net.broker import ServiceBrokerServer


class AdminsInFile(AdminAuthMixin):
    """Look for admins in admins.pub"""

    def pub_key_find(self, key: bytes) -> bool:
        """Compare key with loaded from file."""
        return key in self.conn_mgr.ioc.keys.list()


class AdminsInTPM(AdminAuthMixin):
    """Look for admins in TPM."""

    def pub_key_find(self, key: bytes) -> bool:
        """Call TPM to authenticate key."""
        return False


class Connections(ConnectionManager, ContainerAware):
    """All current connections are registered here."""

    def __init__(self, ioc: Container):
        ConnectionManager.__init__(self)
        ContainerAware.__init__(self, ioc)


class ServerProtocolFile(Protocol, ServerProtoMixin, AdminsInFile):
    """Packet manager that gets admins from file of public keys."""

    def __init__(self, facade: Facade, conn_mgr: ConnectionManager):
        super().__init__(facade, True, conn_mgr)
        self._add_handler(ServiceBrokerServer(self))
        self._add_handler(AuthenticationServer(self))

    def connection_made(self, transport: asyncio.Transport):
        """Add more handlers according to authentication."""
        ServerProtoMixin.connection_made(self, transport)
