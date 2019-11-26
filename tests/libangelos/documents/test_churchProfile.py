from unittest import TestCase

from libangelos.document.profiles import ChurchProfile


class TestChurchProfile(TestCase):
    def setUp(self):
        self.instance = ChurchProfile()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)
