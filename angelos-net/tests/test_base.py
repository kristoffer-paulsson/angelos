import logging
import sys
import tracemalloc
from unittest import TestCase

from angelos.meta.testing import run_async
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import PacketHandler, PacketManager, UnknownPacket, ErrorPacket, Packet, UINT_DATATYPE, \
    UUID_DATATYPE, BYTES_FIX_DATATYPE, BYTES_VAR_DATATYPE


class StubPacket(Packet):
    uint = (UINT_DATATYPE, 100, 200)
    uuid = (UUID_DATATYPE,)
    fixed = (BYTES_FIX_DATATYPE, 128)
    variable = (BYTES_VAR_DATATYPE,)


class TestPacket(TestCase):
    def test_meta(self):
        packet = StubPacket()


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
        self.handler = PacketHandler(PacketManager(self.client))

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.client

    def test_manager(self):
        self.assertIsInstance(self.handler.manager, PacketManager)

    def test_handle_packet(self):
        self.fail()

    @run_async
    async def test_process_unknown(self):
        packet = UnknownPacket(0, 0, 0)
        with self.assertRaises(NotImplementedError):
            await self.handler.process_unknown(packet)

    @run_async
    async def test_process_error(self):
        packet = ErrorPacket(0, 0, 0)
        with self.assertRaises(NotImplementedError):
            await self.handler.process_error(packet)
