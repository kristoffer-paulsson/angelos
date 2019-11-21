from unittest import TestCase

from libangelos.document.profiles import Profile


class TestProfile(TestCase):
    def setUp(self):
        self.instance = Profile()

    def tearDown(self):
        del self.instance

    def test_document(self):
        self.fail()
