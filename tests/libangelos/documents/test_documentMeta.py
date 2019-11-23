from unittest import TestCase

from libangelos.document.model import DocumentMeta


class TestDocumentMeta(TestCase):
    def setUp(self):
        self.instance = DocumentMeta()

    def tearDown(self):
        del self.instance
