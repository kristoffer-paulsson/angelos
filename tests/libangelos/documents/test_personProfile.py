from unittest import TestCase

from libangelos.document.profiles import PersonProfile


class TestPersonProfile(TestCase):
    def setUp(self):
        self.instance = PersonProfile()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
