from unittest import TestCase

from libangelos.document.profiles import PrivateKeys


class TestPrivateKeys(TestCase):
    def setUp(self):
        self.instance = PrivateKeys()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
