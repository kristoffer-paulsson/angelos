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
"""Network client and server classes to connect and listen."""
import asyncio
from ipaddress import IPv4Address, IPv6Address
from typing import Union

from angelos.facade.facade import Facade
from angelos.net.base import PacketManager


class Client(PacketManager):
    """Client of packet manager."""

    SERVER = (False,)

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

    SERVER = (True,)

    @classmethod
    async def listen(
            cls, facade: Facade,
            host: Union[str, IPv4Address, IPv6Address], port: int
    ) -> asyncio.base_events.Server:
        """Start a listening server."""
        return await asyncio.get_running_loop().create_server(lambda: cls(facade), host, port)