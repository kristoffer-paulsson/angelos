import logging
import os
import sys
import tracemalloc
import uuid
from pathlib import Path, PurePosixPath
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.document.document import Document
from angelos.document.model import UuidField
from angelos.document.types import ChurchData
from angelos.facade.facade import Facade
from angelos.lib.const import Const
from angelos.meta.fake import Generate
from angelos.meta.testing import run_async
from angelos.portfolio.portfolio.setup import SetupChurchPortfolio


class StubDocument(Document):
    id = UuidField(init=uuid.uuid4)


class TestMailStorage(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = Path(self.dir.name)
        self.facade = Facade(self.home, self.secret,
            SetupChurchPortfolio().perform(ChurchData(**Generate.church_data()[0]), server=True),
            role=Const.A_ROLE_PRIMARY, server=True
        )

    def tearDown(self) -> None:
        self.facade.close()
        self.dir.cleanup()

    @run_async
    async def test_save(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            self.assertIsInstance(await self.facade.storage.mail.save(filename, StubDocument()), uuid.UUID)

    @run_async
    async def test_delete(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            await self.facade.storage.mail.save(filename, StubDocument())

        for filename in names:
            await self.facade.storage.mail.delete(filename)
            self.assertTrue(await self.facade.storage.mail.archive.isfile(filename))

    @run_async
    async def test_update(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            await self.facade.storage.mail.save(filename, StubDocument())

        for filename in names:
            self.assertIsInstance(await self.facade.storage.mail.update(filename, StubDocument()), uuid.UUID)

    @run_async
    async def test_issuer(self):
        with self.assertRaises(DeprecationWarning):
            await self.facade.storage.mail.issuer(uuid.uuid4())

    @run_async
    async def test_search(self):
        names = [PurePosixPath("/", Generate.filename(".doc")) for _ in range(10)]
        for filename in names:
            await self.facade.storage.mail.save(filename, StubDocument())

        paths = (await self.facade.storage.mail.search()).values()
        for filename in names:
            self.assertIn(filename, paths)
