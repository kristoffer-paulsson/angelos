from unittest import TestCase

from libangelos.document.statements import Trusted


class TestTrusted(TestCase):
    def setUp(self):
        self.instance = Trusted()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
