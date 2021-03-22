import asyncio
import logging
import sys
import tracemalloc
from pathlib import PurePosixPath
from typing import Union
from unittest import TestCase

from angelos.document.domain import Node
from angelos.document.messages import Mail
from angelos.document.utils import Definitions, Helper
from angelos.facade.facade import Facade
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.meta.testing.app import StubServer, StubClient
from angelos.meta.testing.net import FacadeContext, cross_authenticate
from angelos.net.authentication import AuthenticationServer, AuthenticationClient, AuthenticationHandler
from angelos.net.base import ServerProtoMixin, Protocol, ClientProtoMixin, ConnectionManager
from angelos.net.broker import ServiceBrokerServer, ServiceBrokerClient, ServiceBrokerHandler
from angelos.net.mail import MailServer, MailClient, MailHandler
from angelos.portfolio.collection import Portfolio, PrivatePortfolio
from angelos.portfolio.envelope.wrap import WrapEnvelope
from angelos.portfolio.message.create import CreateMail


async def inject_mail(server: Facade, sender: PrivatePortfolio, recipient: Portfolio) -> Mail:
    """Generate one mail to recipient using a facade saving the mail to the outbox."""
    message = CreateMail().perform(sender, recipient).message(
        Generate.lipsum_sentence(), Generate.lipsum(100).decode()).done()
    envelope = WrapEnvelope().perform(sender, recipient, message)
    await server.storage.mail.save(
        PurePosixPath("/" + str(envelope.id) + Helper.extension(Definitions.COM_ENVELOPE)), envelope)
    return message


async def prepare_mail(client: Facade, recipient: Portfolio) -> Mail:
    """Generate one mail to recipient using a facade saving the mail to the outbox."""
    message = CreateMail().perform(client.data.portfolio, recipient).message(
        Generate.lipsum_sentence(), Generate.lipsum(100).decode()).done()
    envelope = WrapEnvelope().perform(client.data.portfolio, recipient, message)
    await client.storage.vault.save(
        PurePosixPath("/messages/outbox/" + str(envelope.id) + Helper.extension(Definitions.COM_ENVELOPE)), envelope)
    return message


class StubServer(Protocol, ServerProtoMixin):
    """Server of packet manager."""

    def __init__(self, facade: Facade, manager: ConnectionManager):
        super().__init__(facade, True, manager)
        self._add_handler(ServiceBrokerServer(self))
        self._add_handler(AuthenticationServer(self))

    def connection_made(self, transport: asyncio.Transport):
        """Add more handlers according to authentication."""
        ServerProtoMixin.connection_made(self, transport)

    def authentication_made(self, portfolio: Portfolio, node: Union[bool, Node]):
        """Indicate that authentication has taken place. Never call from outside, internal use only."""
        Protocol.authentication_made(self, portfolio, node)
        self._add_handler(MailServer(self))


class StubClient(Protocol, ClientProtoMixin):
    """Client of packet manager."""

    def __init__(self, facade: Facade):
        super().__init__(facade)
        self._add_handler(ServiceBrokerClient(self))
        self._add_handler(AuthenticationClient(self))
        self._add_handler(MailClient(self))

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
    async def test_noise(self):
        await cross_authenticate(self.server.facade, self.client2.facade)
        for _ in range(3):
            await inject_mail(
                self.server.facade, self.client1.facade.data.portfolio, self.client2.facade.data.portfolio)
            await prepare_mail(
                self.client2.facade, self.client1.facade.data.portfolio)

        server = await StubServer.listen(self.server.facade, "127.0.0.1", 8080, self.manager)
        task = asyncio.create_task(server.serve_forever())
        await asyncio.sleep(0)

        client = await StubClient.connect(self.client2.facade, "127.0.0.1", 8080)
        self.assertTrue(await client.get_handler(AuthenticationHandler.RANGE).auth_user())
        self.assertTrue(await client.get_handler(ServiceBrokerHandler.RANGE).request(MailHandler.RANGE))
        await client.get_handler(MailHandler.RANGE).exchange()
        await asyncio.sleep(.1)



