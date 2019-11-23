from unittest import TestCase

from libangelos.document.entity_mixin import MinistryMixin


class TestMinistryMixin(TestCase):
    def setUp(self):
        self.instance = MinistryMixin()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)
