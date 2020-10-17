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
import logging
import os

from libangelos.net.client import Client
from libangelos.net.server import Server
from tests.support.lipsum import LIPSUM_RSA_PRIVATE, LIPSUM_RSA_PUBLIC
from tests.support.generate import run_async
from tests.support.stub import StubMaker
from tests.support.testing import BaseTestNetwork


class DummyClient(Client):
    """Dummy client for testing."""
    pass


class DummyServer(Server):
    """Dummy server for testing."""
    pass


class TestConnecting(BaseTestNetwork):
    pref_loglevel = logging.DEBUG
    pref_connectable = True

    server = None
    client = None

    @run_async
    async def setUp(self) -> None:
        """Create client/server network nodes."""
        self.server = await StubMaker.create_server()
        self.client = await StubMaker.create_client()

        with open(os.path.join(self.server.dir.name, "private.key"), "w") as pk:
            pk.write(LIPSUM_RSA_PRIVATE)
        with open(os.path.join(self.server.dir.name, "public.key"), "w") as pk:
            pk.write(LIPSUM_RSA_PUBLIC)

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.server
        del self.client

    @run_async
    async def test_connecting(self):
        """Connect client and server."""
        server = await DummyServer.start(
            self.server.app.ioc,
            host_keys=os.path.join(self.server.dir.name, "private.key"),
            auth_client_keys=os.path.join(self.server.dir.name, "public.key")
        )
        client = DummyClient()
        client.connect()
