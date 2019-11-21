from unittest import TestCase

from libangelos.document.entity_mixin import PersonMixin


class TestPersonMixin(TestCase):
    def setUp(self):
        self.instance = PersonMixin()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()
