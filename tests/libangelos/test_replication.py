#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import logging
from tempfile import TemporaryDirectory

from libangelos.policy.portfolio import PGroup, PortfolioPolicy
from libangelos.policy.verify import StatementPolicy
from libangelos.task.task import TaskWaitress

from angelossim.support import run_async, StubMaker, Operations, Generate, Introspection
from angelossim.testing import BaseTestNetwork


class TestCrossAuthentication(BaseTestNetwork):
    pref_loglevel = logging.DEBUG
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
        files = await Introspection.get_storage_portfolio_file_list(
            self.server.app.ioc.facade.storage.vault,
            self.client.app.ioc.facade.data.portfolio.entity.id
        )

        """ Client <-- Server """
        # Load server data from server vault
        server_data = await self.server.app.ioc.facade.storage.vault.load_portfolio(
            self.server.app.ioc.facade.data.portfolio.entity.id,
            PGroup.SHARE_MAX_COMMUNITY
        )

        # Add server portfolio to client
        await self.client.app.ioc.facade.storage.vault.add_portfolio(server_data)

        files = await Introspection.get_storage_portfolio_file_list(
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
        files = await Introspection.get_storage_portfolio_file_list(
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
        files = await Introspection.get_storage_portfolio_file_list(
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
        files = await Introspection.get_storage_portfolio_file_list(
            self.client.app.ioc.facade.storage.vault,
            self.server.app.ioc.facade.data.portfolio.entity.id
        )
        print(files)

        """ Client (index network) """
        await TaskWaitress().wait_for(self.client.app.ioc.facade.task.network_index)

        # Verify trusted network
        print(await self.client.app.ioc.facade.api.settings.networks())


class TestFullReplication(BaseTestNetwork):
    pref_loglevel = logging.DEBUG
    pref_connectable = True

    server = None
    client1 = None
    client2 = None

    @run_async
    async def setUp(self) -> None:
        """Create client/server network nodes."""
        self.server = await StubMaker.create_server()
        self.client1 = await StubMaker.create_client()
        self.client2 = await StubMaker.create_client()

    def tearDown(self) -> None:
        """Clean up test network"""
        del self.server
        del self.client1
        del self.client2

    @run_async
    async def test_mail_replication_client1_server_client2(self):
        """A complete test of two clients mailing to each other via a server."""
        try:
            # Make all players trust each other
            await Operations.cross_authenticate(self.server.app.ioc.facade, self.client1.app.ioc.facade, True)
            await Operations.cross_authenticate(self.server.app.ioc.facade, self.client2.app.ioc.facade, True)
            await Operations.trust_mutual(self.client1.app.ioc.facade, self.client2.app.ioc.facade)

            mail = await Operations.send_mail(self.client1.app.ioc.facade, self.client2.app.ioc.facade.data.portfolio)
            await self.server.app.listen()

            self.assertIs(
                len(await self.client1.app.ioc.facade.api.mailbox.load_outbox()), 1,
                "Client 1 should have one (1) letter in the outbox before connecting."
            )

            client = await self.client1.app.connect()
            await client.mail()

            self.assertIs(
                len(await self.server.app.ioc.facade.storage.mail.search()), 1,
                "Server should have one (1) letter in its routing mail box after Client 1 connected."
            )
            self.assertIs(
                len(await self.client1.app.ioc.facade.api.mailbox.load_outbox()), 0,
                "Client 1 should have zero (0) letters in its outbox after connecting to server."
            )

            client = await self.client2.app.connect()
            await client.mail()

            inbox = await self.client2.app.ioc.facade.api.mailbox.load_inbox()
            self.assertIs(
                len(inbox), 1,
                "Client 2 should have one (1) letter in its inbox after connecting to the server."
            )
            self.assertIs(
                len(await self.server.app.ioc.facade.storage.mail.search()), 0,
                "Server should have zero (0) letters in its routing mail box after Client 2 connected."
            )

            mail2 = await self.client2.app.ioc.facade.api.mailbox.open_envelope(inbox.pop())
            self.assertEqual(mail.body, mail2.body, "Checking that the sent mail equals the received mail.")

        except Exception as e:
            self.fail(e)
