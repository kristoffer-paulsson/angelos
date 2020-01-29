import logging
import uuid
from tempfile import TemporaryDirectory

from libangelos.archive.portfolio_mixin import PortfolioMixin
from libangelos.policy.portfolio import PGroup
from libangelos.policy.verify import StatementPolicy
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

    async def get_storage_portfolio_file_list(self, storage: PortfolioMixin, eid: uuid.UUID) -> set:
        """Create a set of all files in a portfolio stored in a storage"""
        dirname = storage.portfolio_path(eid)
        return await storage.archive.glob(name="{dir}/*".format(dir=dirname))

    @run_async
    async def test_mail_replication_to_server(self):
        try:
            # Make all players trust each other
            await Operations.trust_mutual(self.server.app.ioc.facade, self.client.app.ioc.facade)
            await Operations.trust_mutual(self.client.app.ioc.facade, self.facade)
            await TaskWaitress().wait_for(self.client.app.ioc.facade.task.network_index)

            print(await self.client.app.ioc.facade.api.settings.networks())
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

    @run_async
    async def test_cross_auth(self):

        logging.info("Client id: %s" % self.client.app.ioc.facade.data.portfolio.entity.id)
        logging.info("Server id: %s" % self.server.app.ioc.facade.data.portfolio.entity.id)

        """ Client --> Server """
        # Export the public client portfolio
        client_data = await self.client.app.ioc.facade.storage.vault.load_portfolio(
            self.client.app.ioc.facade.data.portfolio.entity.id,
            PGroup.SHARE_MAX_USER
        )

        # Add client portfolio to server
        await self.server.app.ioc.facade.storage.vault.add_portfolio(client_data)

        # Verify the client portfolio in server vault
        files = await self.get_storage_portfolio_file_list(
            self.server.app.ioc.facade.storage.vault,
            self.client.app.ioc.facade.data.portfolio.entity.id
        )
        print(files)

        """ Client <-- Server """
        # Load server data from server vault
        server_data = await self.server.app.ioc.facade.storage.vault.load_portfolio(
            self.server.app.ioc.facade.data.portfolio.entity.id,
            PGroup.SHARE_MAX_COMMUNITY
        )

        # Add server portfolio to client
        await self.client.app.ioc.facade.storage.vault.add_portfolio(server_data)

        files = await self.get_storage_portfolio_file_list(
            self.client.app.ioc.facade.storage.vault,
            self.server.app.ioc.facade.data.portfolio.entity.id
        )
        print(files)

        """ Server -" Client """
        # Trust the client portfolio
        trust = StatementPolicy.trusted(
            self.server.app.ioc.facade.data.portfolio,
            self.client.app.ioc.facade.data.portfolio
        )

        # Saving server trust for client to server
        await self.server.app.ioc.facade.storage.vault.docs_to_portfolio(set([trust]))

        # Verify the client portfolio in server vault
        files = await self.get_storage_portfolio_file_list(
            self.server.app.ioc.facade.storage.vault,
            self.client.app.ioc.facade.data.portfolio.entity.id
        )
        print(files)

        """ Client <-- -" Server """
        # Load client data from server vault
        client_data = await self.server.app.ioc.facade.storage.vault.load_portfolio(
            self.client.app.ioc.facade.data.portfolio.entity.id,
            PGroup.SHARE_MAX_USER
        )

        # Saving server trust for client to client
        await self.client.app.ioc.facade.storage.vault.docs_to_portfolio(client_data.owner.trusted)

        # Verify the server trust for client in client vault
        files = await self.get_storage_portfolio_file_list(
            self.client.app.ioc.facade.storage.vault,
            self.server.app.ioc.facade.data.portfolio.entity.id
        )
        print(files)

        """ Client -" Server """
        # Trust the server portfolio
        trust = StatementPolicy.trusted(
            self.client.app.ioc.facade.data.portfolio,
            self.server.app.ioc.facade.data.portfolio
        )

        # Saving client trust for server to client
        await self.client.app.ioc.facade.storage.vault.docs_to_portfolio(set([trust]))

        # Verify the client trust for server in client vault
        files = await self.get_storage_portfolio_file_list(
            self.client.app.ioc.facade.storage.vault,
            self.server.app.ioc.facade.data.portfolio.entity.id
        )
        print(files)

        """ Client (index network) """
        await TaskWaitress().wait_for(self.client.app.ioc.facade.task.network_index)

        # Verify trusted network
        print(await self.client.app.ioc.facade.api.settings.networks())


