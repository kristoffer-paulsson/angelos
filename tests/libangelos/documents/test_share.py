from unittest import TestCase

from libangelos.document.messages import Share


class TestShare(TestCase):
    def setUp(self):
        self.instance = Share()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
