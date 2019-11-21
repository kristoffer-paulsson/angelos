from unittest import TestCase

from libangelos.document.entities import Person


class TestPerson(TestCase):
    def setUp(self):
        self.instance = Person()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
