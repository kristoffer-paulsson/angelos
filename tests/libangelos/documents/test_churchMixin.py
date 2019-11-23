from unittest import TestCase

from libangelos.document.entity_mixin import ChurchMixin


class TestChurchMixin(TestCase):
    def setUp(self):
        self.instance = ChurchMixin()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)
