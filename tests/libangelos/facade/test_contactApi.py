import asyncio
import logging
import os
import pprint
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from tests.libangelos.common import run_async

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupPersonOperation

from dummy.support import Generate


class TestContactAPI(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()

        cls.secret = os.urandom(32)
        cls.dir = TemporaryDirectory()
        cls.home = cls.dir.name
        cls.server = False

        @run_async
        async def contacts():
            """Generate a facade and inject random contacts."""
            portfolio = SetupPersonOperation.create(Generate.person_data()[0], server=cls.server)
            cls.facade = None
            cls.facade = await Facade.setup(
                cls.home, cls.secret,
                Const.A_ROLE_PRIMARY, cls.server, portfolio=portfolio
            )

            for person in Generate.person_data(10):
                await cls.facade.storage.vault.add_portfolio(SetupPersonOperation.create(person, server=False))
        contacts()

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""
        if not cls.facade.closed:
            cls.facade.close()
        cls.dir.cleanup()

    def setUp(self) -> None:
        pass

    def tearDown(self) -> None:
        pass

    async def _open(self):
        return await Facade.open(self.home, self.secret)

    @run_async
    async def test_load_all(self):
        try:
            self.facade.task.contact_sync.invoke()
            await asyncio.sleep(5)
            print(await self.facade.api.contact.load_all())
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_load_blocked(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_block(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_unblock(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_load_friends(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_unfriend(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_favorite(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_unfavorite(self):
        try:
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_remove(self):
        try:
            pass
        except Exception as e:
            self.fail(e)
