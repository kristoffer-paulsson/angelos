from unittest import TestCase

from libangelos.document.document import OwnerMixin


class TestOwnerMixin(TestCase):
    def setUp(self):
        self.instance = OwnerMixin()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()
