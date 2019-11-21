from unittest import TestCase

from libangelos.document.profiles import IssueMixin


class TestIssueMixin(TestCase):
    def setUp(self):
        self.instance = IssueMixin()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()
