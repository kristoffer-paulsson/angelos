from unittest import TestCase

from libangelos.document.messages import Mail


class TestMail(TestCase):
    def setUp(self):
        self.instance = Mail()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
