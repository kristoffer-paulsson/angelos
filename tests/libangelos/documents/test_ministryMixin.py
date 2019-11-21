from unittest import TestCase

from libangelos.document.profiles import MinistryMixin


class TestMinistryMixin(TestCase):
    def setUp(self):
        self.instance = MinistryMixin()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()
