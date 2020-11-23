import io
import logging
import os
import sys
import tracemalloc
import uuid
from pathlib import Path, PurePosixPath
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.document.document import Document, UpdatedMixin, OwnerMixin
from angelos.document.model import UuidField
from angelos.document.types import PersonData
from angelos.facade.facade import Facade
from angelos.lib.const import Const
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio


class StubDocument(Document):
    id = UuidField(init=uuid.uuid4)


class StubDocumentUpdated(Document, UpdatedMixin):
    id = UuidField(init=uuid.uuid4)


class StubDocumentOwner(Document, OwnerMixin):
    id = UuidField(init=uuid.uuid4)


class TestVaultStorage(TestCase):
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

    def test_setup(self):
        self.facade.close()  # Setup is done at facade creation, closing and opening asserts.
        self.facade = Facade(self.home, self.secret)

    @run_async
    async def test_save(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            self.assertIsInstance(await self.facade.storage.vault.save(filename, StubDocument()), uuid.UUID)

    @run_async
    async def test_delete(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            await self.facade.storage.vault.save(filename, StubDocument())

        for filename in names:
            await self.facade.storage.vault.delete(filename)
            self.assertTrue(await self.facade.storage.vault.archive.isfile(filename))

    @run_async
    async def test_link(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            await self.facade.storage.vault.save(filename, StubDocument())

        for filename in names:
            self.assertIsInstance(await self.facade.storage.vault.link(
                PurePosixPath("/", Generate.filename(".doc")), filename), uuid.UUID)

    @run_async
    async def test_update(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            await self.facade.storage.vault.save(filename, StubDocument())

        for filename in names:
            self.assertIsInstance(await self.facade.storage.vault.update(filename, StubDocument()), uuid.UUID)

    @run_async
    async def test_issuer(self):
        with self.assertRaises(DeprecationWarning):
            await self.facade.storage.vault.issuer(uuid.uuid4())

    @run_async
    async def test_search(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            await self.facade.storage.vault.save(filename, StubDocument())

        paths = (await self.facade.storage.vault.search()).values()
        for filename in names:
            self.assertIn(filename, paths)

    @run_async
    async def test_search_docs(self):
        with self.assertRaises(DeprecationWarning):
            await self.facade.storage.vault.search_docs(self.facade.data.portfolio.entity.id)

    @run_async
    async def test_save_settings(self):
        settings = io.StringIO(Generate.lipsum().decode())
        await self.facade.storage.vault.save_settings("monkeys.csv", settings)

    @run_async
    async def test_load_settings(self):
        settings = io.StringIO(Generate.lipsum().decode())
        await self.facade.storage.vault.save_settings("monkeys.csv", settings)
        data = await self.facade.storage.vault.load_settings("monkeys.csv")
        self.assertEqual(settings.getvalue(), data.getvalue())
