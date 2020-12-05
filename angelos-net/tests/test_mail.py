import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.app import StubServer, StubClient
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import ServerManagerMixin, PacketManager, ClientManagerMixin
from angelos.net.mail import MailServer, MailClient


class StubServer(ServerManagerMixin, PacketManager):
    """Stub protocol server."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(MailServer(self))


class StubClient(ClientManagerMixin, PacketManager):
    """Stub protocol client."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(MailClient(self))

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        PacketManager.connection_made(self, transport)

        self._ranges[MailClient.RANGE].start()


class TestMailHandler(TestCase):
    client = None
    server = None

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

    @run_async
    async def setUp(self) -> None:
        """Create client/server network nodes."""
        self.client = FacadeContext.create_client()
        self.server = FacadeContext.create_server()

    @run_async
    async def test_run(self):
        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client.facade, "127.0.0.1", 8080)
        # client.send_packet(4, 1, b"Hello, world!")
