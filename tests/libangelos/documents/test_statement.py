from unittest import TestCase

from libangelos.document.statements import Statement


class TestStatement(TestCase):
    def setUp(self):
        self.instance = Statement()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()
