from unittest import TestCase

from libangelos.document.messages import Message


class TestMessage(TestCase):
    def setUp(self):
        self.instance = Message()

    def tearDown(self):
        del self.instance
