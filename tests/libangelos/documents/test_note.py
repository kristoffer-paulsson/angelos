from unittest import TestCase

from libangelos.document.profiles import Note


class TestNote(TestCase):
    def setUp(self):
        self.instance = Note()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
