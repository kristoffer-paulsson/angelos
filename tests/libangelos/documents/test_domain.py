from unittest import TestCase

from libangelos.document.domain import Domain


class TestDomain(TestCase):
    def setUp(self):
        self.instance = Domain()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
