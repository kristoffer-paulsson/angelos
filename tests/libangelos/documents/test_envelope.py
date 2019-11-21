from unittest import TestCase

from libangelos.document.envelope import Envelope


class TestEnvelope(TestCase):
    def setUp(self):
        self.instance = Envelope()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
