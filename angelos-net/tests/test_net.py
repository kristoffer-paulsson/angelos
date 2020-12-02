import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext
from angelos.net.net import Server, Client


class NetworkTest(TestCase):
    server = None
    client = None

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

    @run_async
    async def setUp(self) -> None:
        """Create client/server network nodes."""
        self.server = FacadeContext.create_server()
        self.client = FacadeContext.create_client()

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.server
        del self.client

    @run_async
    async def test_run(self):
        server = await Server.listen(self.server.facade, "127.0.0.1", 8080)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await Client.connect(self.client.facade, "127.0.0.1", 8080)
        client.send_packet(4, 1, b"Hello, world!")