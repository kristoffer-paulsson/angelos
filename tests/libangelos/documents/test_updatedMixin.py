from unittest import TestCase

from libangelos.document.document import UpdatedMixin


class TestUpdatedMixin(TestCase):
    def setUp(self):
        self.instance = UpdatedMixin()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_renew(self):
        self.fail()
