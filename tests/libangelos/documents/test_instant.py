from unittest import TestCase

from libangelos.document.messages import Instant


class TestInstant(TestCase):
    def setUp(self):
        self.instance = Instant()

    def tearDown(self):
        del self.instance

    def test_document(self):
        self.fail()
