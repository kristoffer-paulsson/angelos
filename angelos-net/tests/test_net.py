import asyncio
import logging
import sys
import tracemalloc
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.document.types import ChurchData, PersonData
from angelos.facade.facade import Facade
from angelos.lib.const import Const
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.net.net import Server, Client
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.portfolio.setup import SetupChurchPortfolio, SetupPersonPortfolio


class FacadeContext:
    """Environmental context for a facade."""

    def __init__(self, portfolio: PrivatePortfolio, server: bool):
        self.dir = TemporaryDirectory()
        self.secret = Generate.new_secret()
        self.facade = Facade(Path(self.dir.name), self.secret, portfolio, Const.A_ROLE_PRIMARY, server)

    def __del__(self):
        self.facade.close()
        self.dir.cleanup()

    @classmethod
    def create_server(cls) -> "FacadeContext":
        """Create a stub server."""
        return cls(SetupChurchPortfolio().perform(
            ChurchData(**Generate.church_data()[0]), server=True), True)

    @classmethod
    def create_client(cls) -> "FacadeContext":
        """Create a stub client."""
        return cls(SetupPersonPortfolio().perform(
            PersonData(**Generate.person_data()[0]), server=False), False)


class NetworkTest(TestCase):
    server = None
    client = None

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

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.server
        del self.client

    @run_async
    async def test_run(self):
        server = await Server.listen(self.server.facade, "127.0.0.1", 8080)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await Client.connect(self.client.facade, "127.0.0.1", 8080)
        client.send_packet(4, 1, b"Hello, world!")