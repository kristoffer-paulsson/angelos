from unittest import TestCase

from libangelos.document.messages import Attachment


class TestAttachment(TestCase):
    def setUp(self):
        self.instance = Attachment()

    def tearDown(self):
        del self.instance

    def test_document(self):
        self.fail()