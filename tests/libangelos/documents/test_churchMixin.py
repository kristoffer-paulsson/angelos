from unittest import TestCase

from libangelos.document.entity_mixin import ChurchMixin


class TestChurchMixin(TestCase):
    def setUp(self):
        self.instance = ChurchMixin()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()
