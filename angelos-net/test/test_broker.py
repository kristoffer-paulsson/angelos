import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.app import StubServer, StubClient
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import ServerProtoMixin, Protocol, ClientProtoMixin, ConnectionManager, Handler, StateMode
from angelos.net.broker import ServiceBrokerServer, ServiceBrokerClient, ServiceBrokerHandler


class StubHandler(Handler):

    LEVEL = 10
    RANGE = 500

    ST_VERSION = 0x01

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_VERSION: (StateMode.MEDIATE, b"stub-0.1"),
        }, dict())


class StubHandlerClient(StubHandler):

    def __init__(self, manager: "Protocol"):
        StubHandler.__init__(self, manager)


class StubHandlerServer(StubHandler):

    def __init__(self, manager: "Protocol"):
        StubHandler.__init__(self, manager)


class StubServer(Protocol, ServerProtoMixin):
    """Server of packet manager."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(StubHandlerServer(self))
        self._add_handler(ServiceBrokerServer(self))

    def connection_made(self, transport: asyncio.Transport):
        """Add more handlers according to authentication."""
        ServerProtoMixin.connection_made(self, transport)


class StubClient(Protocol, ClientProtoMixin):
    """Client of packet manager."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(StubHandlerClient(self))
        self._add_handler(ServiceBrokerClient(self))

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        Protocol.connection_made(self, transport)


class TestMailHandler(TestCase):
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
    async def test_start(self):

        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client1.facade, "127.0.0.1", 8080)
        self.assertTrue(await client.get_handler(ServiceBrokerHandler.RANGE).request(StubHandler.RANGE))
        await asyncio.sleep(0)
        self.assertFalse(await client.get_handler(ServiceBrokerHandler.RANGE).request(StubHandler.RANGE-2))
        # await client.get_handler(MailHandler.RANGE).start()
        await asyncio.sleep(.1)



