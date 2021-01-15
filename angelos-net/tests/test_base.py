import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import ConnectionManager, ServerProtoMixin, Protocol, ClientProtoMixin, Handler



#### Testing handler state transfer ####


class StubStateHandler(Handler):
    LEVEL = 1
    RANGE = 1

    ST_STUB = 0x01
    ST_ANOTHER = 0x02

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_STUB: b"test",
            self.ST_ANOTHER: b"next",
        }, dict(), 8)


class StubStateClient(StubStateHandler):
    async def test_tell(self) -> int:
        await self._tell_state(self.ST_STUB)
        return await self._tell_state(self.ST_ANOTHER)


class StubStateServer(StubStateHandler):

    async def test_show(self):
        await self._show_state(self.ST_STUB)


class StubServer(ServerProtoMixin, Protocol):
    """Stub protocol server."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(StubStateServer(self))


class StubClient(ClientProtoMixin, Protocol):
    """Stub protocol client."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(StubStateClient(self))

    def connection_made(self, transport: asyncio.Transport):
        """Start mail replication immediately."""
        Protocol.connection_made(self, transport)


class TestHandler(TestCase):
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
    async def test__tell_state(self):
        """Test state tell mechanics."""
        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client.facade, "127.0.0.1", 8080)
        await client.get_handler(StubStateHandler.RANGE).test_tell()
        await asyncio.sleep(.1)