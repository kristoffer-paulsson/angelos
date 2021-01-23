import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import ConnectionManager, ServerProtoMixin, Protocol, ClientProtoMixin, Handler



#### Stub handler one-1 ####

class StubHandler1(Handler):
    """Stub handler 1"""

    LEVEL = 1
    RANGE = 1

    ST_VERSION = 0x01

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_VERSION: b"stub1-0.1",
        }, dict(), 0)


class StubHandlerClient1(StubHandler1):

    def __init__(self, manager: "Protocol"):
        StubHandler1.__init__(self, manager)

    async def test(self):
        return await self._tell_state(self.ST_VERSION)


class StubHandlerServer1(StubHandler1):

    def __init__(self, manager: "Protocol"):
        StubHandler1.__init__(self, manager)


#### Stub handler two-2 ####

class StubHandler2(Handler):
    """Stub handler 2"""

    LEVEL = 2
    RANGE = 2

    ST_VERSION = 0x01

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_VERSION: b"stub2-0.1",
        }, dict(), 0)


class StubHandlerClient2(StubHandler2):

    def __init__(self, manager: "Protocol"):
        StubHandler2.__init__(self, manager)

    async def test(self):
        return await self._tell_state(self.ST_VERSION)


class StubHandlerServer2(StubHandler2):

    def __init__(self, manager: "Protocol"):
        StubHandler2.__init__(self, manager)


#### Stub handler three-3 ####

class StubHandler3(Handler):
    """Stub handler 3"""

    LEVEL = 3
    RANGE = 3

    ST_VERSION = 0x01

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_VERSION: b"stub3-0.1",
        }, dict(), 0)


class StubHandlerClient3(StubHandler3):

    def __init__(self, manager: "Protocol"):
        StubHandler3.__init__(self, manager)

    async def test(self):
        return await self._tell_state(self.ST_VERSION)


class StubHandlerServer3(StubHandler3):

    def __init__(self, manager: "Protocol"):
        StubHandler3.__init__(self, manager)


#### Stub handler four-4 ####

class StubHandler4(Handler):
    """Stub handler 4"""

    LEVEL = 4
    RANGE = 4

    ST_VERSION = 0x01

    def __init__(self, manager: "Protocol"):
        Handler.__init__(self, manager, {
            self.ST_VERSION: b"stub4-0.1",
        }, dict(), 0)


class StubHandlerClient4(StubHandler4):

    def __init__(self, manager: "Protocol"):
        StubHandler4.__init__(self, manager)

    async def test(self):
        return await self._tell_state(self.ST_VERSION)


class StubHandlerServer4(StubHandler4):

    def __init__(self, manager: "Protocol"):
        StubHandler4.__init__(self, manager)


#### Client and Server ####

class StubServer(Protocol, ServerProtoMixin):
    """Server of packet manager."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(StubHandlerServer1(self))
        self._add_handler(StubHandlerServer2(self))
        self._add_handler(StubHandlerServer3(self))
        self._add_handler(StubHandlerServer4(self))

    def connection_made(self, transport: asyncio.Transport):
        """Add more handlers according to authentication."""
        ServerProtoMixin.connection_made(self, transport)


class StubClient(Protocol, ClientProtoMixin):
    """Client of packet manager."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(StubHandlerClient1(self))
        self._add_handler(StubHandlerClient2(self))
        self._add_handler(StubHandlerClient3(self))
        self._add_handler(StubHandlerClient4(self))

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
        await client.get_handler(StubHandler1.RANGE).test()
        await client.get_handler(StubHandler2.RANGE).test()
        await client.get_handler(StubHandler3.RANGE).test()
        await client.get_handler(StubHandler4.RANGE).test()
        await asyncio.sleep(.1)