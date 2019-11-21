from unittest import TestCase

from libangelos.document.entities import Church


class TestChurch(TestCase):
    def setUp(self):
        self.instance = Church()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
