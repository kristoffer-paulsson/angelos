from unittest import TestCase

from libangelos.document.profiles import Social


class TestSocial(TestCase):
    def setUp(self):
        self.instance = Social()

    def tearDown(self):
        del self.instance

    def test_document(self):
        self.fail()
