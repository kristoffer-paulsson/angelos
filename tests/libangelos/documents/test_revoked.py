from unittest import TestCase

from libangelos.document.statements import Revoked


class TestRevoked(TestCase):
    def setUp(self):
        self.instance = Revoked()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
