from unittest import TestCase

from libangelos.document.messages import Report


class TestReport(TestCase):
    def setUp(self):
        self.instance = Report()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
