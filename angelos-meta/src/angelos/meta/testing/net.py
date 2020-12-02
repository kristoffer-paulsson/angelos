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
from angelos.document.types import ChurchData, PersonData
from angelos.facade.facade import Facade, Path
from angelos.lib.const import Const
from angelos.meta.fake import Generate

from angelos.meta.testing import run_async
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