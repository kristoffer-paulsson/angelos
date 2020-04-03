import logging
import os
import sys
import tracemalloc
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.ar72 import StreamManager


class BaseArchiveTestCase(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=logging.INFO)

        cls.secret = os.urandom(32)

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""

    def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""

        self.dir = TemporaryDirectory()
        self.home = self.dir.name

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.dir.cleanup()


class TestStreamBlock(BaseArchiveTestCase):
    def test_load(self):
        self.fail()


class StreamManagerStub(StreamManager):
    pass


class TestDataStream(BaseArchiveTestCase):
    pass


class TestStreamRegistry(BaseArchiveTestCase):
    def test_load(self):
        self.fail()


class TestStreamManager(BaseArchiveTestCase):
    def test_run(self):
        try:
            mgr = StreamManagerStub(os.path.join(self.home, "test.ar7"), self.secret)
        except Exception as e:
            self.fail(e)
