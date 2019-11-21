from unittest import TestCase

from libangelos.document.profiles import Address


class TestAddress(TestCase):
    def setUp(self):
        self.instance = Address()

    def tearDown(self):
        del self.instance

    def test_document(self):
        self.fail()
