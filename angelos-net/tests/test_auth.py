import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext
from angelos.net.auth import AuthenticationServer, AuthenticationClient, AuthenticationHandler
from angelos.net.base import ConnectionManager, ServerProtoMixin, Protocol, ClientProtoMixin


class StubServer(Protocol, ServerProtoMixin):
    """Stub protocol server."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(AuthenticationServer(self))


class StubClient(Protocol, ClientProtoMixin):
    """Stub protocol client."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(AuthenticationClient(self))

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        Protocol.connection_made(self, transport)
        # self._ranges[MailClient.RANGE].start()


class TestAuthenticationServer(TestCase):
    client1 = None
    client2 = None
    server = None
    manager = None

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

    @run_async
    async def setUp(self) -> None:
        """Create client/server network nodes."""
        self.client1 = FacadeContext.create_client()
        self.client2 = FacadeContext.create_client()
        self.server = FacadeContext.create_server()
        self.manager = ConnectionManager()

    @run_async
    async def test_auth_user(self):
        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client1.facade, "127.0.0.1", 8080)
        await client.get_handler(AuthenticationHandler.RANGE).auth_user()
        await asyncio.sleep(.1)
