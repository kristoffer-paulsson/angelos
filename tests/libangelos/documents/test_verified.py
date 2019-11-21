from unittest import TestCase

from libangelos.document.statements import Verified


class TestVerified(TestCase):
    def setUp(self):
        self.instance = Verified()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
