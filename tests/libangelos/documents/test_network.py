from unittest import TestCase

from libangelos.document.domain import Network


class TestNetwork(TestCase):
    def setUp(self):
        self.instance = Network()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
