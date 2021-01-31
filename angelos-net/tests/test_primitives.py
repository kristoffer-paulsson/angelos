import asyncio
import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.common.misc import SyncCallable
from angelos.facade.facade import Facade
from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import Protocol, ClientProtoMixin, ServerProtoMixin, ConnectionManager, ConfirmCode
from angelos.net.primitives import Handler, StateMixin, StateMode, NetworkState


class StateHandler(Handler, StateMixin):
    """Test handler for primitives."""

    LEVEL = 10
    RANGE = 500

    ST_VERSION = 0x01
    ST_ONCE = 0x02
    ST_REPRISE = 0x03
    ST_FACT = 0x04

    def __init__(self, manager: "Protocol"):
        server = manager.is_server()
        Handler.__init__(self, manager)
        StateMixin.__init__(self, {
            self.ST_VERSION: (StateMode.MEDIATE, b"stub-0.1"),
            self.ST_ONCE: (StateMode.ONCE, b"xx1" if server else b"xx5"),
            self.ST_REPRISE: (StateMode.REPRISE, b"xx2" if server else b"xx6"),
            self.ST_FACT: (StateMode.FACT, b"xx3" if server else b"xx7"),
        })

    def get_state(self, state: int) -> NetworkState:
        return self._states[state]


class ClientStateStub(StateHandler):

    def __init__(self, manager: "Protocol"):
        StateHandler.__init__(self, manager)

    async def do_mediate(self):
        return await self._call_mediate(self.ST_VERSION, [b"stub-0.3", b"stub-0.2", b"stub-0.1"])


class ServerStateStub(StateHandler):

    def __init__(self, manager: "Protocol"):
        StateHandler.__init__(self, manager)
        self._states[self.ST_VERSION].upgrade(SyncCallable(self._mediate_version))
        default = SyncCallable(lambda value: ConfirmCode.YES)
        self._states[self.ST_ONCE].upgrade(default)
        self._states[self.ST_REPRISE].upgrade(default)
        self._states[self.ST_FACT].upgrade(default)

    def _mediate_version(self, value: bytes) -> int:
        """Test version compatibility."""
        return ConfirmCode.YES if value == self._states[self.ST_VERSION].value else ConfirmCode.NO

    async def do_show(self):
        return await self._call_show(self.ST_ONCE)


class ClientStub(Protocol, ClientProtoMixin):
    """Client of packet manager."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(ClientStateStub(self))


class ServerStub(Protocol, ServerProtoMixin):
    """Server of packet manager."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(ServerStateStub(self))

    def connection_made(self, transport: asyncio.Transport):
        """Add more handlers according to authentication."""
        ServerProtoMixin.connection_made(self, transport)


class StateMixinTest(TestCase):
    server = None
    client = None
    manager = None

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
        self.manager = ConnectionManager()

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.server
        del self.client

    @run_async
    async def test__call_mediate(self):
        """Test that StateMixin._call_mediate behaves as expected."""
        server = await ServerStub.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await ClientStub.connect(self.client.facade, "127.0.0.1", 8080)
        self.assertEqual(b"stub-0.1", await client.get_handler(StateHandler.RANGE).do_mediate())
        await asyncio.sleep(.1)

    @run_async
    async def test__call_show(self):
        """Test that StateMixin._call_ahow behaves as expected."""
        server = await ServerStub.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await ClientStub.connect(self.client.facade, "127.0.0.1", 8080)
        await asyncio.sleep(.1)

        conn = list(self.manager)
        handler = conn[0].get_handler(StateHandler.RANGE)
        self.assertEqual(handler.get_state(handler.ST_ONCE).value, b"xx1")
        self.assertEqual(await handler.do_show(), b"xx5")
        # await asyncio.sleep(.1)
        # machine = handler.get_state(handler.ST_ONCE)
        # print(machine.value, machine.frozen, machine.mode, machine.state)