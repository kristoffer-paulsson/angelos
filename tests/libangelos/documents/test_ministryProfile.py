from unittest import TestCase

from libangelos.document.profiles import MinistryProfile


class TestMinistryProfile(TestCase):
    def setUp(self):
        self.instance = MinistryProfile()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
