from unittest import TestCase

from libangelos.document.envelope import Header


class TestHeader(TestCase):
    def setUp(self):
        self.instance = Header()

    def tearDown(self):
        del self.instance
