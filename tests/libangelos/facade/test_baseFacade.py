import os
import asyncio
import tracemalloc

from collections import namedtuple
from tempfile import TemporaryDirectory
from unittest import TestCase
from libangelos.facade.base import BaseFacade


tracemalloc.start()


class TestBaseFacade(TestCase):
    def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.instance = BaseFacade(self.home, os.urandom(32), None)

    def tearDown(self) -> None:
        del self.instance
        self.dir.cleanup()

    def test__post_init(self):
        with self.assertRaises(NotImplementedError):
            asyncio.run(self.instance._post_init())

    def test_path(self):
        self.assertEqual(self.instance.path, self.home)

    def test_secret(self):
        self.assertIs(type(self.instance.secret), bytes)
        self.assertIs(len(self.instance.secret), 32)

    def test_closed(self):
        self.assertFalse(self.instance.closed)
        self.instance.close()
        self.assertTrue(self.instance.closed)

    def test_data(self):
        self.assertIs(type(self.instance.data), dict)

    def test_api(self):
        self.assertIs(type(self.instance.api), dict)

    def test_task(self):
        self.assertIs(type(self.instance.task), dict)

    def test_archive(self):
        self.assertIs(type(self.instance.archive), dict)

    def test_setup(self):
        with self.assertRaises(NotImplementedError):
            asyncio.run(BaseFacade.setup(self.home, self.instance.secret, 0, None))

    def test_open(self):
        with self.assertRaises(NotImplementedError):
            asyncio.run(BaseFacade.open(self.home, self.instance.secret))

    def test_close(self):
        try:
            self.instance.close()
            self.assertTrue(self.instance.closed)
        except Exception as e:
            self.fail(e)
