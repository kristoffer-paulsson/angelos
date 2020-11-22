#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
from angelos.document.document import DocType

from angelos.common.misc import Misc
from angelos.document.messages import Mail
from angelos.facade.facade import Facade
from angelos.lib.policy.message import MessagePolicy, EnvelopePolicy
from angelos.lib.policy.portfolio import DOCUMENT_PATH
from angelos.lib.policy.verify import StatementPolicy
from angelos.lib.task.task import TaskWaitress
from angelos.meta.fake import Generate
from angelos.meta.testing.app import StubMaker
from angelos.portfolio.collection import Portfolio
from angelos.portfolio.utils import Groups


class Operations:
    """Application, facade and portfolio operations."""

    @classmethod
    async def trust_mutual(cls, f1: Facade, f2: Facade):
        """Make two facades mutually trust each other."""

        docs = set()
        docs.add(StatementPolicy.trusted(f1.data.portfolio, f2.data.portfolio))
        docs.add(StatementPolicy.trusted(f2.data.portfolio, f1.data.portfolio))

        await f1.storage.vault.add_portfolio(f2.data.portfolio.to_portfolio())
        await f2.storage.vault.add_portfolio(f1.data.portfolio.to_portfolio())

        await f1.storage.vault.statements_portfolio(docs)
        await f2.storage.vault.statements_portfolio(docs)

        await TaskWaitress().wait_for(f1.task.contact_sync)
        await TaskWaitress().wait_for(f2.task.contact_sync)

    @classmethod
    async def send_mail(cls, sender: Facade, recipient: Portfolio) -> Mail:
        """Generate one mail to recipient using a facade saving the mail to the outbox."""
        builder = MessagePolicy.mail(sender.data.portfolio, recipient)
        message = builder.message(Generate.lipsum_sentence(), Generate.lipsum().decode()).done()
        envelope = EnvelopePolicy.wrap(sender.data.portfolio, recipient, message)
        await sender.api.mailbox.save_outbox(envelope)
        return message

    @classmethod
    async def inject_mail(cls, server: "Facade", sender: "Facade", recipient: "Portfolio") -> "Mail":
        """Generate one mail to recipient using a facade injecting the mail to the server."""
        builder = MessagePolicy.mail(sender.data.portfolio, recipient)
        message = builder.message(Generate.lipsum_sentence(), Generate.lipsum().decode()).done()
        envelope = EnvelopePolicy.wrap(sender.data.portfolio, recipient, message)
        await server.storage.mail.save(
            DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir="", file=envelope.id
            ), envelope)
        return message

    @classmethod
    async def portfolios(cls, num: int, portfolio_list: list, server: bool = False, types: int = 0):
        """Generate random portfolios based on input data."""

        for person in StubMaker.TYPES[types][1](num):
            portfolio_list.append(StubMaker.TYPES[types][0].create(person, server=server))

    @classmethod
    async def cross_authenticate(cls, server: Facade, client: Facade, preselect: bool = True) -> bool:
        """Cross authenticate a server and a client.

        The facade will import each others portfolios, then they will trust each other and update the portfolios.
        Also the networks will be indexed at the client and the recent network preselected.
        When the client and server are cross authenticated, the client should be able to connect to the server.

        Args:
            server (Facade):
                Facade of the server
            client (Facade):
                Facade of the client
            preselect (bool):
                If the server should be the primary network in the client facade.

        Returns (bool):
            Whether the server is successfully indexed as a trusted network

        """
        # Client --> Server
        # Export the public client portfolio
        client_data = await client.storage.vault.load_portfolio(
            client.data.portfolio.entity.id, Groups.SHARE_MAX_USER)

        # Add client portfolio to server
        await server.storage.vault.add_portfolio(client_data)

        # Load server data from server vault
        server_data = await server.storage.vault.load_portfolio(
            server.data.portfolio.entity.id, Groups.SHARE_MAX_COMMUNITY)

        # Add server portfolio to client
        await client.storage.vault.add_portfolio(server_data)

        # Server -" Client
        # Trust the client portfolio
        trust = StatementPolicy.trusted(
            server.data.portfolio, client.data.portfolio)

        # Saving server trust for client to server
        await server.storage.vault.statements_portfolio(set([trust]))

        # Client <-- -" Server
        # Load client data from server vault
        client_data = await server.storage.vault.load_portfolio(
            client.data.portfolio.entity.id, Groups.SHARE_MAX_USER)

        # Saving server trust for client to client
        await client.storage.vault.statements_portfolio(client_data.owner.trusted)

        # Client -" Server
        # Trust the server portfolio
        trust = StatementPolicy.trusted(client.data.portfolio, server.data.portfolio)

        # Saving client trust for server to client
        await client.storage.vault.statements_portfolio(set([trust]))

        # Client (index network)
        await TaskWaitress().wait_for(client.task.network_index)

        # Verify trusted network
        networks = {net[0] for net in await client.api.settings.networks() if net[1]}
        print("Networks:", networks)
        if str(server.data.portfolio.entity.id) not in networks:
            return False

        if preselect:
            client.data.client["CurrentNetwork"] = server.data.portfolio.entity.id
            await Misc.sleep()

        return True