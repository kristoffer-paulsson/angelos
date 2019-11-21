from unittest import TestCase

from libangelos.document.entities import Ministry


class TestMinistry(TestCase):
    def setUp(self):
        self.instance = Ministry()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
