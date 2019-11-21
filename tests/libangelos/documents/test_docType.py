from unittest import TestCase

from libangelos.document.document import DocType


class TestDocType(TestCase):
    def setUp(self):
        self.instance = DocType()

    def tearDown(self):
        del self.instance

    def test_document(self):
        self.fail()
