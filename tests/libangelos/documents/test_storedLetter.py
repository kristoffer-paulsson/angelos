from unittest import TestCase

from libangelos.document.misc import StoredLetter


class TestStoredLetter(TestCase):
    def setUp(self):
        self.instance = StoredLetter()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
