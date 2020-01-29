import logging
import uuid
from tempfile import TemporaryDirectory

from libangelos.task.task import TaskWaitress

from dummy.support import run_async, StubMaker, Operations, Generate
from dummy.testing import BaseTestNetwork


class TestNetwork(BaseTestNetwork):
    pref_loglevel = logging.INFO
    pref_connectable = True

    server = None
    client = None
    facade = None

    @run_async
    async def setUp(self) -> None:
        self.server = await StubMaker.create_server()
        self.client = await StubMaker.create_client()
        self.dir = TemporaryDirectory()
        self.facade = await StubMaker.create_person_facace(self.dir.name, Generate.new_secret())

    def tearDown(self) -> None:
        self.dir.cleanup()
        del self.server
        del self.client
        del self.facade

    @run_async
    async def test_mail_replication_to_server(self):
        try:
            # Make all players trust each other
            await Operations.trust_mutual(self.server.app.ioc.facade, self.client.app.ioc.facade)
            await Operations.trust_mutual(self.client.app.ioc.facade, self.facade)
            await TaskWaitress().wait_for(self.client.app.ioc.facade.task.network_index)

            network = uuid.UUID(list(filter(lambda x: x[1], await self.client.app.ioc.facade.api.settings.networks()))[0][0])
            self.assertEqual(network, self.server.app.ioc.facade.data.portfolio.entity.id)
            self.client.app.ioc.facade.data.client["CurrentNetwork"] = network

            mail = await Operations.send_mail(self.client.app.ioc.facade, self.facade.data.portfolio)
            await self.server.app.listen()
            self.assertIs(len(await self.client.app.ioc.facade.api.mailbox.load_outbox()), 1)

            client = await self.client.app.connect()
            await client.mail()

            self.assertIs(len(await self.server.app.ioc.facade.storage.mail.search()), 1)
            self.assertIs(len(await self.client.app.ioc.facade.api.mailbox.load_outbox()), 0)

        except Exception as e:
            self.fail(e)

    @run_async
    async def test_mail_replication_to_client(self):
        try:
            # Make all players trust each other
            await Operations.trust_mutual(self.server.app.ioc.facade, self.client.app.ioc.facade)
            await Operations.trust_mutual(self.client.app.ioc.facade, self.facade)
            await TaskWaitress().wait_for(self.client.app.ioc.facade.task.network_index)

            network = uuid.UUID(list(filter(lambda x: x[1], await self.client.app.ioc.facade.api.settings.networks()))[0][0])
            self.assertEqual(network, self.server.app.ioc.facade.data.portfolio.entity.id)
            self.client.app.ioc.facade.data.client["CurrentNetwork"] = network

            mail = await Operations.inject_mail(
                self.server.app.ioc.facade, self.facade, self.client.app.ioc.facade.data.portfolio)
            await self.server.app.listen()
            self.assertIs(len(await self.server.app.ioc.facade.storage.mail.search()), 1)

            client = await self.client.app.connect()
            await client.mail()

            self.assertIs(len(await self.client.app.ioc.facade.api.mailbox.load_inbox()), 1)
            self.assertIs(len(await self.server.app.ioc.facade.storage.mail.search()), 0)

        except Exception as e:
            self.fail(e)
