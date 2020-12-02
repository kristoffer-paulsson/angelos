import datetime
import logging
import sys
import tracemalloc
import uuid
from unittest import TestCase

from angelos.common.misc import Misc
from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import PacketHandler, PacketManager, UnknownPacket, ErrorPacket, default, ext_hook, \
    DataType, Packet, r, UNKNOWN_PACKET


class StubPacket(Packet, fields=("uint", "uuid", "fixed", "variable", "date"), fields_info=(
        (DataType.UINT, 100, 200), (DataType.UUID,), (DataType.BYTES_FIX, 128), (DataType.BYTES_VAR, 5, 20),
        (DataType.DATETIME,))):
    """Stub packet for testing features."""
    pass


class StubHandler(PacketHandler):
    """Base handler for stub."""
    LEVEL = 1
    RANGE = 511

    RLOW = r(RANGE)[0]

    PKT_STUB = RLOW + 1

    PACKETS = {
        PKT_STUB: StubPacket,
    }

    PROCESS = dict()

    async def process_stub(self, packet: StubPacket):
        """Handle an unknown packet response.

        This method MUST never return an unknown or error in order
        to prevent an infinite loop over the network.
        """
        print(packet)
        raise NotImplementedError()


class StubHandlerClient(StubHandler):
    """Client side stub handler."""

    PROCESS = {
        StubHandler.PKT_STUB: "process_stub",
    }


class StubHandlerServer(StubHandler):
    """Server side stub handler."""

    PROCESS = {
        StubHandler.PKT_STUB: "process_stub",
    }


class TestExtType(TestCase):
    """Test custom ExtTypes (DataTypes) for the protocol."""

    def test_UINT(self):
        value = 2 ** 63
        ext = default(value)
        self.assertEqual(ext.code, DataType.UINT)
        self.assertEqual(ext_hook(*ext), value)

    def test_UUID(self):
        value = uuid.uuid4()
        ext = default(value)
        self.assertEqual(ext.code, DataType.UUID)
        self.assertEqual(ext_hook(*ext), value)

    def test_BYTES_FIX(self):
        value = bytes(b"Hello, world!")
        ext = default(value)
        self.assertEqual(ext.code, DataType.BYTES_FIX)
        self.assertEqual(ext_hook(*ext), value)

    def test_BYTES_VAR(self):
        value = bytearray(b"Hello, world!")
        ext = default(value)
        self.assertEqual(ext.code, DataType.BYTES_VAR)
        self.assertEqual(ext_hook(*ext), value)

    def test_DATETIME(self):
        value = datetime.datetime.now().replace(microsecond=0)
        ext = default(value)
        self.assertEqual(ext.code, DataType.DATETIME)
        self.assertEqual(ext_hook(*ext), value)


class TestPacket(TestCase):
    def test_unpack(self):
        packet = StubPacket(
            150, uuid.uuid4(), bytes(128), bytearray(b"Hello, world!"),
            datetime.datetime.now())
        self.assertEqual(packet.tuple, StubPacket.unpack(bytes(packet)).tuple)

        with self.assertRaises(ValueError):
            StubPacket(
                99, uuid.uuid4(), bytes(128), bytearray(b"Hello, world!"),
                datetime.datetime.now())

        with self.assertRaises(ValueError):
            StubPacket(
                250, uuid.uuid4(), bytes(128), bytearray(b"Hello, world!"),
                datetime.datetime.now())

        with self.assertRaises(ValueError):
            StubPacket(
                150, uuid.uuid4(), bytes(148), bytearray(b"Hello, world!"),
                datetime.datetime.now())

        with self.assertRaises(ValueError):
            StubPacket(
                150, uuid.uuid4(), bytes(100), bytearray(b"Hello, world!"),
                datetime.datetime.now())

        with self.assertRaises(ValueError):
            StubPacket(
                150, uuid.uuid4(), bytes(128), bytearray(b"foo"),
                datetime.datetime.now())

        with self.assertRaises(ValueError):
            StubPacket(
                150, uuid.uuid4(), bytes(128), bytearray(b"Hello, world! Foo, bar, baz?"),
                datetime.datetime.now())

    def test_tuple(self):
        data = (150, uuid.uuid4(), bytes(128), bytearray(b"Hello, world!"),
                datetime.datetime.now().replace(microsecond=0))
        packet = StubPacket(*data)

        self.assertIsInstance(packet.tuple, tuple)
        self.assertEqual(packet.tuple, data)
        self.assertIs(packet.uint, 150)
        self.assertIsInstance(packet.uuid, uuid.UUID)
        self.assertIs(len(packet.fixed), 128)
        self.assertEqual(packet.variable, b"Hello, world!")

        with self.assertRaises(AttributeError):
            packet.foobar

        with self.assertRaises(ValueError):
            StubPacket(*data[:4])


class TestErrorPacket(TestCase):
    def test_error(self):
        packet = ErrorPacket(100, 200, 100, 1)
        self.assertIs(packet.type, 100)
        self.assertIs(packet.level, 200)
        self.assertIs(packet.process, 100)
        self.assertIs(packet.error, 1)


class TestUnknownPacket(TestCase):
    def test_unknown(self):
        packet = UnknownPacket(100, 200, 100)
        self.assertIs(packet.type, 100)
        self.assertIs(packet.level, 200)
        self.assertIs(packet.process, 100)


class TestPacketHandler(TestCase):
    client = None
    handler = None

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

    @run_async
    async def setUp(self) -> None:
        """Create client/server network nodes."""
        self.client = FacadeContext.create_client()
        self.handler = StubHandlerClient(PacketManager(self.client))

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.client

    def test_manager(self):
        self.assertIsInstance(self.handler.manager, PacketManager)

    @run_async
    async def test_handle_packet(self):
        packet = StubPacket(
            150, uuid.uuid4(), bytes(128), bytearray(b"Hello, world!"),
            datetime.datetime.now())
        self.handler.handle_packet(StubHandler.PKT_STUB, bytes(packet))
        await Misc.sleep()

    @run_async
    async def test_process_unknown(self):
        with self.assertRaises(NotImplementedError):
            await self.handler.process_unknown(UnknownPacket(0, 0, 0))

    @run_async
    async def test_process_error(self):
        with self.assertRaises(NotImplementedError):
            await self.handler.process_error(ErrorPacket(0, 0, 0, 0))
