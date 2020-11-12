import asyncio
import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.facade.facade import Facade
from angelos.lib.const import Const
from angelos.lib.policy.types import PersonData
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio


class TestFacade(TestCase):

    @classmethod
    def setUpClass(cls) -> None:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = self.dir.name

    def tearDown(self) -> None:
        self.dir.cleanup()

    @run_async
    async def test_facade(self):
        facade = Facade(self.home, self.secret,
            SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=True
        )
        facade.storage.vault
        facade.close()
