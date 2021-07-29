import logging
import os
import sys
import tracemalloc
import uuid
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.document.types import PersonData
from angelos.facade.facade import Facade
from angelos.lib.const import Const
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio


class TestSettingsAPI(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = Path(self.dir.name)
        self.facade = Facade(self.home, self.secret,
            SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=False
        )

    def tearDown(self) -> None:
        self.facade.close()
        self.dir.cleanup()

    @run_async
    async def test_load_preferences(self):
        await self.facade.api.settings.load_preferences()

    @run_async
    async def test_save_preferences(self):
        self.assertTrue(await self.facade.api.settings.save_preferences())

    @run_async
    async def test_load_set(self):
        data = {
            ("roland", str(uuid.uuid4()), 1),
            ("bertil", str(uuid.uuid4()), 2),
            ("august", str(uuid.uuid4()), 3)
        }
        await self.facade.api.settings.save_set("alerts.csv", data)
        reloaded = await self.facade.api.settings.load_set("alerts.csv")
        self.assertEqual(data, reloaded)

    @run_async
    async def test_save_set(self):
        data = {
            ("roland", str(uuid.uuid4()), 1),
            ("bertil", str(uuid.uuid4()), 2),
            ("august", str(uuid.uuid4()), 3)
        }
        self.assertTrue(await self.facade.api.settings.save_set("alerts.csv", data))

    @run_async
    async def test_networks(self):
        await self.facade.api.settings.networks()
