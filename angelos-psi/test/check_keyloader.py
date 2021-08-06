import unittest
from unittest import TestCase

from angelos.psi.keyloader import KeyLoader


class TestKeyLoader(TestCase):
    MESSAGE = KeyLoader.new()

    @unittest.skipIf(getattr(KeyLoader, "dummy", False), "Not implemented")
    def test_02_get(self):
        msg = KeyLoader.get()
        self.assertEqual(msg, self.MESSAGE)

    @unittest.skipIf(getattr(KeyLoader, "dummy", False), "Not implemented")
    def test_01_set(self):
        KeyLoader.set(self.MESSAGE)

    @unittest.skipIf(getattr(KeyLoader, "dummy", False), "Not implemented")
    def test_03_redo(self):
        KeyLoader.redo()
        self.assertEqual(KeyLoader.get(), self.MESSAGE)
