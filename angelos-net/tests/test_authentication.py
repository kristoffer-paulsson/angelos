import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

import angelos
from angelos.bin.nacl import Signer, NaCl
from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext, cross_authenticate
from angelos.net.authentication import AuthenticationServer, AuthenticationClient, AuthenticationHandler, AdminAuthMixin
from angelos.net.base import ConnectionManager, ServerProtoMixin, Protocol, ClientProtoMixin


class StubServer(Protocol, ServerProtoMixin, AdminAuthMixin):
    """Stub protocol server."""

    admin = b""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(AuthenticationServer(self))

    def pub_key_find(self, key: bytes) -> bool:
        return key == self.admin


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
    client = None
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
        self.client = FacadeContext.create_client()
        self.server = FacadeContext.create_server()
        self.admin = None
        self.manager = ConnectionManager()

    @run_async
    async def test_auth_user(self):
        await cross_authenticate(self.server.facade, self.client.facade)

        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client.facade, "127.0.0.1", 8080)
        self.assertTrue(await client.get_handler(AuthenticationHandler.RANGE).auth_user())
        await asyncio.sleep(.1)

    @run_async
    async def test_auth_admin(self):
        signer = Signer(NaCl.random_bytes(32))
        self.admin = FacadeContext.create_admin(signer)
        StubServer.admin = signer.vk

        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.admin.facade, "127.0.0.1", 8080)
        self.assertTrue(await client.get_handler(AuthenticationHandler.RANGE).auth_admin())
        await asyncio.sleep(.1)
