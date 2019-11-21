from unittest import TestCase

from libangelos.document.document import Document


class TestDocument(TestCase):
    def setUp(self):
        self.instance = Document()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test__check_type(self):
        self.fail()

    def test__check_validate(self):
        self.fail()

    def test_expires_soon(self):
        self.fail()
