import io
import logging
import os
import sys
import tracemalloc
import uuid
from tempfile import TemporaryDirectory
from unittest import TestCase

from archive7.archive import Archive7
from archive7.base import BlockTuple
from archive7.fs import EntryRecord
from archive7.operations import BlockProcessor, CorruptDataFilter, InvalidMetaFilter, SyncDecryptor

from angelossim.support import run_async


class TestBlockProcessor(BlockProcessor):
    def __init__(self, fileobj: io.FileIO, secret: bytes):
        BlockProcessor.__init__(self, fileobj, SyncDecryptor(secret))

    def _filters(self):
        return (
            CorruptDataFilter(),
            InvalidMetaFilter()
        )

    def process(self, position: int, block: BlockTuple, result: tuple):
        if result[0]:
            print("Block %s has corrupt data" % position)
        if result[1]:
            print("Block %s self-referencing pointers" % position)


class BaseArchiveTestCase(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)

        cls.secret = os.urandom(32)

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""

    def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""

        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.filename = os.path.join(self.home, "test.ar7")

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.dir.cleanup()


class TestHeader(TestCase):
    def test_meta_unpack(self):
        self.fail()


class TestArchive7(BaseArchiveTestCase):
    def analyze(self):
        fileobj = open(self.filename, "rb+")
        processor = TestBlockProcessor(fileobj, self.secret)
        processor.run()
        for f in processor.filter:
            self.assertFalse(f.data)
        fileobj.close()

    def test_setup(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_open(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            archive.close()

            archive.open(self.filename, self.secret)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_closed(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            self.assertFalse(archive.closed)
            archive.close()
            self.assertTrue(archive.closed)
        except Exception as e:
            self.fail(e)

    def test_close(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_stats(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            header = archive.stats()
            archive.close()

            archive.open(self.filename, self.secret)
            header2 = archive.stats()
            archive.close()

            self.assertEqual(header.id, header2.id)
            self.assertEqual(header.created, header2.created)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_info(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            await archive.mkdir("/first")
            await archive.mkfile("/first/second.bin", os.urandom(2 ** 18))

            entry = await archive.info("/first/second.bin")
            self.assertIsInstance(entry, EntryRecord)
            archive.close()
        except Exception as e:
            self.fail(e)

    def test_glob(self):
        self.fail()

    @run_async
    async def test_move(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            await archive.mkdir("/first")
            await archive.mkdir("/second")
            await archive.mkfile("/first/third.bin", os.urandom(2 ** 18))

            self.assertTrue(archive.isfile("/first/third.bin"))
            await archive.move("/first/third.bin", "/second")
            self.assertTrue(archive.isfile("/second/third.bin"))
            self.assertFalse(archive.isfile("/first/third.bin"))
            archive.close()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_chmod(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            await archive.mkfile("/first.bin", os.urandom(2 ** 18))
            await archive.chmod(
                "/first.bin", owner=uuid.UUID(int=3),
                deleted=False, user="tester", group="tester", perms=0o755
            )
            archive.close()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_remove(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            await archive.mkdir("/first")
            await archive.mkfile("/first/second.bin", os.urandom(2 ** 18))

            self.assertTrue(archive.isdir("/first"))
            self.assertTrue(archive.isfile("/first/second.bin"))

            await archive.remove("/first/second.bin")
            self.assertFalse(archive.isfile("/first/second.bin"))
            archive.close()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_rename(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            await archive.mkdir("/first")
            await archive.mkfile("/first/second.bin", os.urandom(2 ** 18))

            self.assertTrue(archive.isdir("/first"))
            self.assertTrue(archive.isfile("/first/second.bin"))

            await archive.rename("/first/second.bin", "third.db")
            self.assertTrue(archive.isfile("/first/third.db"))
            archive.close()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_isdir(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            await archive.mkdir("/first")
            await archive.mkdir("/first/second")
            await archive.mkfile("/first/third.bin", os.urandom(2 ** 18))

            self.assertTrue(archive.isdir("/first"))
            self.assertTrue(archive.isdir("/first/second"))
            self.assertFalse(archive.isdir("/first/third.bin"))
            archive.close()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_isfile(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            await archive.mkdir("/first")
            await archive.mkdir("/first/second")
            await archive.mkfile("/first/second.bin", os.urandom(2 ** 18))

            self.assertFalse(archive.isfile("/first"))
            self.assertFalse(archive.isfile("/first/second"))
            self.assertTrue(archive.isfile("/first/second.bin"))
            archive.close()

            self.analyze()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_islink(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            self.assertIsInstance(await archive.mkdir("/first"), uuid.UUID)
            self.assertIsInstance(await archive.mkfile("/first/second.bin", os.urandom(2 ** 18)), uuid.UUID)
            self.assertIsInstance(await archive.link("/first/third", "/first/second.bin"), uuid.UUID)

            self.assertTrue(archive.isdir("/first"))
            self.assertTrue(archive.isfile("/first/second.bin"))
            self.assertTrue(archive.islink("/first/third"))
            archive.close()

            self.analyze()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_mkdir(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            self.assertIsInstance(await archive.mkdir("/first"), uuid.UUID)
            self.assertIsInstance(await archive.mkdir("/first/second"), uuid.UUID)
            self.assertIsInstance(await archive.mkdir("/first/second/third"), uuid.UUID)
            archive.close()

            self.analyze()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_mkfile(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            self.assertIsInstance(await archive.mkfile("/first.bin", os.urandom(2 ** 20)), uuid.UUID)
            archive.close()

            self.analyze()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_link(self):
        try:
            archive = Archive7.setup(self.filename, self.secret)
            self.assertIsInstance(await archive.mkdir("/first"), uuid.UUID)
            self.assertIsInstance(await archive.mkfile("/first/second.bin", os.urandom(2 ** 18)), uuid.UUID)
            self.assertIsInstance(await archive.link("/first/third", "/first/second.bin"), uuid.UUID)
            archive.close()

            self.analyze()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_save(self):
        try:
            filename = "/first.bin"

            archive = Archive7.setup(self.filename, self.secret)
            self.assertIsInstance(await archive.mkfile(filename, os.urandom(2 ** 20)), uuid.UUID)
            self.assertIsInstance(await archive.save(filename, os.urandom(2 ** 19)), uuid.UUID)
            archive.close()

            self.analyze()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_load(self):
        try:
            data = os.urandom(2 ** 20)
            filename = "/first.bin"

            archive = Archive7.setup(self.filename, self.secret)
            self.assertIsInstance(await archive.mkfile(filename, data), uuid.UUID)
            self.assertEqual(await archive.load(filename), data)
            archive.close()
        except Exception as e:
            self.fail(e)

