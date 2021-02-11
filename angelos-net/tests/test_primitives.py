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
from angelos.net.primitives import Handler, StateMixin, StateMode, NetworkState, ReuseStateError, GrabStateError, \
    SessionMixin, NetworkSession


SESH_TYPE_STUB = 0x01


class StubSession(NetworkSession):
    """Test stub session with states."""

    ST_MEDIATE = 0x01
    ST_ONCE = 0x02
    ST_REPRISE = 0x03
    ST_FACT = 0x04

    def __init__(self, server: bool, session: int):
        NetworkSession.__init__(self, SESH_TYPE_STUB, session, {
            self.ST_MEDIATE: (StateMode.MEDIATE, "10.0"),
            self.ST_ONCE: (StateMode.ONCE, "xf11"),
            self.ST_REPRISE: (StateMode.REPRISE, "xf12"),
            self.ST_FACT: (StateMode.FACT, "xf13")
        }, server)


class StateHandler(Handler, StateMixin, SessionMixin):
    """Test handler for primitives."""

    LEVEL = 10
    RANGE = 500

    MAX_SESH = 4

    ST_VERSION = 0x01
    ST_ONCE = 0x02
    ST_REPRISE = 0x03
    ST_FACT = 0x04

    SESH_STUB = SESH_TYPE_STUB

    def __init__(self, manager: "Protocol"):
        server = manager.is_server()
        Handler.__init__(self, manager)
        StateMixin.__init__(self, {
            self.ST_VERSION: (StateMode.MEDIATE, b"stub-0.1"),
            self.ST_ONCE: (StateMode.ONCE, b"xx1" if server else b"xx5"),
            self.ST_REPRISE: (StateMode.REPRISE, b"xx2" if server else b"xx6"),
            self.ST_FACT: (StateMode.FACT, b"xx3" if server else b"xx7"),
        })
        SessionMixin.__init__(self, {
            self.SESH_STUB, StubSession
        })

    def get_state(self, state: int) -> NetworkState:
        return self._states[state]


class ClientStateStub(StateHandler):

    def __init__(self, manager: "Protocol"):
        StateHandler.__init__(self, manager)
        default = SyncCallable(lambda value: ConfirmCode.YES)
        self._states[self.ST_FACT].upgrade(default)

    async def do_mediate(self, handler: int = StateHandler.ST_VERSION):
        return await self._call_mediate(handler, [b"stub-0.3", b"stub-0.2", b"stub-0.1"])

    async def do_tell(self, handler: int = StateHandler.ST_ONCE):
        return await self._call_tell(handler)

    async def do_tell_r(self, handler: int = StateHandler.ST_VERSION):
        return await self._call_tell(handler)

    async def do_query(self, handler: int = StateHandler.ST_FACT):
        return await self._call_query(handler)


class ServerStateStub(StateHandler):

    def __init__(self, manager: "Protocol"):
        StateHandler.__init__(self, manager)
        self._states[self.ST_VERSION].upgrade(SyncCallable(self._mediate_version))
        default = SyncCallable(lambda value: ConfirmCode.YES)
        self._states[self.ST_ONCE].upgrade(default)
        self._states[self.ST_REPRISE].upgrade(default)

    def _mediate_version(self, value: bytes) -> int:
        """Test version compatibility."""
        return ConfirmCode.YES if value == self._states[self.ST_VERSION].value else ConfirmCode.NO

    async def do_show(self, handler: int = StateHandler.ST_ONCE):
        return await self._call_show(handler)


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
    """Testing of network state exchange."""
    # TODO: Make tests for misuse cases.

    server = None
    client = None
    manager = None
    server_handler = None
    client_handler = None

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
        self.server_handler = None
        self.client_handler = None
        self.server = None
        self.client = None

    async def environment(self, handler: int, side: bool = True) -> Handler:
        """Setup an environment with client and server.

        Args:
            handler (int):
                Settle on which handler by range.
            side (bool):
                Get from client (True) or server (False)

        Returns (Handler):
            Protocol handler class instance to test on.
        """
        server = await ServerStub.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await ClientStub.connect(self.client.facade, "127.0.0.1", 8080)
        await asyncio.sleep(0)

        self.client_handler = client.get_handler(handler)
        self.server_handler = list(self.manager)[0].get_handler(handler)

    @run_async
    async def test__call_mediate(self):
        """Test that StateMixin._call_mediate behaves as expected."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(b"stub-0.1", await self.client_handler.do_mediate())

    @run_async
    async def test__call_mediate_1(self):
        """Test that StateMixin._call_mediate on ONCE."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(b"stub-0.3", await self.client_handler.do_mediate(StateHandler.ST_ONCE))

    @run_async
    async def test__call_mediate_2(self):
        """Test that StateMixin._call_mediate on REPRISE."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(b"stub-0.3", await self.client_handler.do_mediate(StateHandler.ST_REPRISE))

    @run_async
    async def test__call_mediate_3(self):
        """Test that StateMixin._call_mediate on FACT."""
        with self.assertRaises(ReuseStateError):
            await self.environment(StateHandler.RANGE)
            await self.client_handler.do_mediate(StateHandler.ST_FACT)

    @run_async
    async def test__call_mediate_4(self):
        """Test that StateMixin._call_mediate behaves on MEDIATE where the server grabs its own state as 'us'."""
        await self.environment(StateHandler.RANGE)
        self.server_handler.get_state(StateHandler.ST_VERSION).us()
        self.assertEqual(b"stub-0.1", await self.client_handler.do_mediate())

    @run_async
    async def test__call_mediate_5(self):
        """Test that StateMixin._call_mediate behaves on MEDIATE where the server grabs its own state as 'them'."""
        with self.assertRaises(GrabStateError):
            await self.environment(StateHandler.RANGE)
            self.server_handler.get_state(StateHandler.ST_VERSION).them()
            self.assertEqual(b"stub-0.1", await self.client_handler.do_mediate())

    @run_async
    async def test__call_show(self):
        """Test that StateMixin._call_show behaves as expected."""
        await self.environment(StateHandler.RANGE, False)
        self.assertEqual(await self.server_handler.do_show(), b"xx5")

    @run_async
    async def test__call_show_1(self):
        """Test that StateMixin._call_show behaves on MEDIATE."""
        with self.assertRaises(ReuseStateError):
            await self.environment(StateHandler.RANGE, False)
            await self.server_handler.do_show(StateHandler.ST_VERSION)

    @run_async
    async def test__call_show_2(self):
        """Test that StateMixin._call_show behaves on REPRISE."""
        with self.assertRaises(ReuseStateError):
            await self.environment(StateHandler.RANGE, False)
            await self.server_handler.do_show(StateHandler.ST_REPRISE)

    @run_async
    async def test__call_show_3(self):
        """Test that StateMixin._call_show behaves on FACT."""
        with self.assertRaises(ReuseStateError):
            await self.environment(StateHandler.RANGE, False)
            await self.server_handler.do_show(StateHandler.ST_FACT)

    @run_async
    async def test__call_show_4(self):
        """Test that StateMixin._call_show behaves on ONCE where the client grabs its own state as 'us'."""
        with self.assertRaises(GrabStateError):
            await self.environment(StateHandler.RANGE, False)
            self.client_handler.get_state(StateHandler.ST_ONCE).us()
            self.assertEqual(await self.server_handler.do_show(), b"xx5")

    @run_async
    async def test__call_show_5(self):
        """Test that StateMixin._call_show behaves on ONCE where the client grabs its own state as 'them'."""
        with self.assertRaises(GrabStateError):
            await self.environment(StateHandler.RANGE, False)
            self.client_handler.get_state(StateHandler.ST_ONCE).them()
            self.assertEqual(await self.server_handler.do_show(), b"xx5")

    @run_async
    async def test__call_tell(self):
        """Test that StateMixin._call_tell behaves as expected."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(await self.client_handler.do_tell(), b"xx5")

    @run_async
    async def test__call_tell_1(self):
        """Test that StateMixin._call_tell behaves on MEDIATE."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(await self.client_handler.do_tell(StateHandler.ST_VERSION), b"stub-0.1")

    @run_async
    async def test__call_tell_2(self):
        """Test that StateMixin._call_tell behaves on REPRISE."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(await self.client_handler.do_tell(StateHandler.ST_REPRISE), b"xx6")

    @run_async
    async def test__call_tell_3(self):
        """Test that StateMixin._call_tell behaves on FACT."""
        with self.assertRaises(ReuseStateError):
            await self.environment(StateHandler.RANGE)
            await self.client_handler.do_tell(StateHandler.ST_FACT)

    @run_async
    async def test__call_tell_4(self):
        """Test that StateMixin._call_tell behaves on ONCE where the client grabs its own state as 'us'."""
        await self.environment(StateHandler.RANGE)
        self.server_handler.get_state(StateHandler.ST_ONCE).us()
        self.assertEqual(await self.client_handler.do_tell(), b"xx5")

    @run_async
    async def test__call_tell_5(self):
        """Test that StateMixin._call_tell behaves on ONCE where the client grabs its own state as 'them'."""
        with self.assertRaises(GrabStateError):
            await self.environment(StateHandler.RANGE)
            self.server_handler.get_state(StateHandler.ST_ONCE).them()
            self.assertEqual(await self.client_handler.do_tell(), b"xx5")

    @run_async
    async def test__call_query(self):
        """Test that StateMixin._call_query behaves as expected."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(await self.client_handler.do_query(), (1, b"xx3"))

    @run_async
    async def test__call_query_1(self):
        """Test that StateMixin._call_query behaves on MEDIATE."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(await self.client_handler.do_query(StateHandler.ST_VERSION), (None, b"stub-0.1"))

    @run_async
    async def test__call_query_2(self):
        """Test that StateMixin._call_query behaves on ONCE."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(await self.client_handler.do_query(StateHandler.ST_ONCE), (None, b"xx1"))

    @run_async
    async def test__call_query_3(self):
        """Test that StateMixin._call_query behaves on REPRISE."""
        await self.environment(StateHandler.RANGE)
        self.assertEqual(await self.client_handler.do_query(StateHandler.ST_REPRISE), (None, b"xx2"))

    @run_async
    async def test__call_query_4(self):
        """Test that StateMixin._call_query behaves on FACT where the client grabs its own state as 'us'."""
        await self.environment(StateHandler.RANGE)
        self.server_handler.get_state(StateHandler.ST_FACT).us()
        self.assertEqual(await self.client_handler.do_query(), (1, b"xx3"))

    @run_async
    async def test__call_query_5(self):
        """Test that StateMixin._call_query behaves on FACT where the client grabs its own state as 'them'."""
        await self.environment(StateHandler.RANGE)
        self.server_handler.get_state(StateHandler.ST_FACT).them()
        self.assertEqual(await self.client_handler.do_query(), (1, b"xx3"))