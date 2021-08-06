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
import logging
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

import asyncssh
from angelos.bin.nacl import Signer, NaCl
from angelos.ctl.support import AdminFacade
from angelos.document.types import ChurchData, PersonData
from angelos.facade.facade import Facade, Path
from angelos.lib.const import Const
from angelos.meta.fake import Generate

from angelos.meta.testing import run_async
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.portfolio.setup import SetupChurchPortfolio, SetupPersonPortfolio
from angelos.portfolio.utils import Groups


async def cross_authenticate(server: Facade, client: Facade) -> bool:
    # Client --> Server
    # Export the public client portfolio
    client_data = await client.storage.vault.load_portfolio(
        client.data.portfolio.entity.id, Groups.SHARE_MAX_USER)

    # Add client portfolio to server
    await server.storage.vault.accept_portfolio(client_data)

    # Load server data from server vault
    server_data = await server.storage.vault.load_portfolio(
        server.data.portfolio.entity.id, Groups.SHARE_MAX_COMMUNITY)

    # Add server portfolio to client
    await client.storage.vault.accept_portfolio(server_data)

    # Server -" Client
    # Trust the client portfolio
    # trust = StatementPolicy.trusted(server.data.portfolio, client.data.portfolio)

    # Saving server trust for client to server
    # await server.storage.vault.statements_portfolio(set([trust]))

    # Client <-- -" Server
    # Load client data from server vault
    # client_data = await server.storage.vault.load_portfolio(client.data.portfolio.entity.id, Groups.SHARE_MAX_USER)

    # Saving server trust for client to client
    # await client.storage.vault.statements_portfolio(client_data.owner.trusted)

    # Client -" Server
    # Trust the server portfolio
    # trust = StatementPolicy.trusted(client.data.portfolio, server.data.portfolio)

    # Saving client trust for server to client
    # await client.storage.vault.statements_portfolio(set([trust]))

    return True


class FacadeContext:
    """Environmental context for a facade."""

    def __init__(self, portfolio: PrivatePortfolio, server: bool, admin: Signer = False):
        self.dir = TemporaryDirectory()
        self.secret = Generate.new_secret()
        if admin:
            self.facade = AdminFacade.setup(admin)
        else:
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

    @classmethod
    def create_admin(cls, signer: Signer = Signer(NaCl.random_bytes(32))) -> "FacadeContext":
        """Create a stub admin."""
        return cls(None, server=False, admin=signer)


# FIXME:
#    Implement this one somewhere.
"""
import importlib
modules = LibraryScanner(str(Path("./src")), **scan).list()
for module in modules:
    print(module)
    importlib.import_module(module)
"""


class BaseTestNetwork(TestCase):
    """Base test for facade based unit testing."""

    pref_loglevel = logging.ERROR

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.pref_loglevel)
        asyncssh.logging.set_log_level(cls.pref_loglevel)

    @run_async
    async def setUp(self) -> None:
        pass

    def tearDown(self) -> None:
        pass