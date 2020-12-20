import asyncio
import logging
import sys
import tracemalloc
import uuid
from unittest import TestCase

from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.app import StubServer, StubClient
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import ServerProtoMixin, Protocol, \
    ClientProtoMixin, ConnectionManager
from angelos.net.mail import MailServer, MailClient, MailHandler


class StubServer(ServerProtoMixin, Protocol):
    """Stub protocol server."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(MailServer(self))


class StubClient(ClientProtoMixin, Protocol):
    """Stub protocol client."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(MailClient(self))

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        Protocol.connection_made(self, transport)
        # self._ranges[MailClient.RANGE].start()


class TestMailHandler(TestCase):
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
        self.manager = ConnectionManager()

    @run_async
    async def test_tell_state(self):
        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client.facade, "127.0.0.1", 8080)
        print(await client.get_handler(MailHandler.RANGE).tell_state(MailHandler.ST_ALL))

    @run_async
    async def test_show_state(self):
        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client.facade, "127.0.0.1", 8080)
        for c in self.manager:
            await c.get_handler(MailHandler.RANGE).show_state(MailHandler.ST_ALL)
            await asyncio.sleep(.1)

    @run_async
    async def test_open_session(self):
        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client.facade, "127.0.0.1", 8080)
        session = await client.get_handler(MailHandler.RANGE).open_session(MailHandler.SESH_ALL)

        tuple(self.manager)[0].get_handler(MailHandler.RANGE).session_done(MailHandler.SESH_ALL, session)
        await asyncio.sleep(0)

        await client.get_handler(MailHandler.RANGE).get_session(session).own.event.wait()
        await client.get_handler(MailHandler.RANGE).stop_session(MailHandler.SESH_ALL, session)

        await asyncio.sleep(1)

    @run_async
    async def test_start(self):
        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client.facade, "127.0.0.1", 8080)
        await client.get_handler(MailHandler.RANGE).start(uuid.uuid4())
        await asyncio.sleep(.1)



