from unittest import TestCase

from angelos.psi.keyloader import KeyLoader


class TestKeyLoader(TestCase):
    MESSAGE = KeyLoader.new()

    def test_02_get(self):
        msg = KeyLoader.get()
        self.assertEqual(msg, self.MESSAGE)

    def test_01_set(self):
        KeyLoader.set(self.MESSAGE)

    def test_03_redo(self):
        KeyLoader.redo()
        self.assertEqual(KeyLoader.get(), self.MESSAGE)
