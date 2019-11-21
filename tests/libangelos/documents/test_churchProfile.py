from unittest import TestCase

from libangelos.document.profiles import ChurchProfile


class TestChurchProfile(TestCase):
    def setUp(self):
        self.instance = ChurchProfile()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
