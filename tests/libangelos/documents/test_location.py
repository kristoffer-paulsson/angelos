from unittest import TestCase

from libangelos.document.domain import Location


class TestLocation(TestCase):
    def setUp(self):
        self.instance = Location()

    def tearDown(self):
        del self.instance
