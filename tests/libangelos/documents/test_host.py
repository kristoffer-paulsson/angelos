from unittest import TestCase

from libangelos.document.domain import Host


class TestHost(TestCase):
    def setUp(self):
        self.instance = Host()

    def tearDown(self):
        del self.instance
