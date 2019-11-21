from unittest import TestCase

from libangelos.document.domain import Node


class TestNode(TestCase):
    def setUp(self):
        self.instance = Node()

    def tearDown(self):
        del self.instance

    def test__validate(self):
        self.fail()

    def test_validate(self):
        self.fail()
