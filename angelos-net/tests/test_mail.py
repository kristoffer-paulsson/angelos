import asyncio
import logging
import sys
import tracemalloc
import uuid
from pathlib import PurePosixPath
from unittest import TestCase

from angelos.document.messages import Mail
from angelos.document.utils import Definitions, Helper
from angelos.facade.facade import Facade
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.meta.testing.app import StubServer, StubClient
from angelos.meta.testing.net import FacadeContext
from angelos.net.base import ServerProtoMixin, Protocol, \
    ClientProtoMixin, ConnectionManager
from angelos.net.mail import MailServer, MailClient, MailHandler
from angelos.portfolio.collection import Portfolio, PrivatePortfolio
from angelos.portfolio.envelope.wrap import WrapEnvelope
from angelos.portfolio.message.create import CreateMail


async def inject_mail(server: Facade, sender: PrivatePortfolio, recipient: Portfolio) -> Mail:
    """Generate one mail to recipient using a facade saving the mail to the outbox."""
    message = CreateMail().perform(sender, recipient).message(
        Generate.lipsum_sentence(), Generate.lipsum().decode()).done()
    envelope = WrapEnvelope().perform(sender, recipient, message)
    await server.storage.mail.save(
        PurePosixPath("/" + str(envelope.id) + Helper.extension(Definitions.COM_ENVELOPE)), envelope)
    return message


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
        for _ in range(10):
            await inject_mail(
                self.server.facade, self.client1.facade.data.portfolio, self.client2.facade.data.portfolio)

        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client1.facade, "127.0.0.1", 8080)
        await client.get_handler(MailHandler.RANGE).start()
        await asyncio.sleep(.1)



