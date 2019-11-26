import datetime

from unittest import TestCase

from libangelos.error import DocumentShortExpiry
from libangelos.document.envelope import Envelope


class TestEnvelope(TestCase):
    def setUp(self):
        self.instance = Envelope()

    def tearDown(self):
        del self.instance

    def test__check_expiry_period(self):
        try:
            stub = Envelope()
            stub._check_expiry_period()
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentShortExpiry) as context:
            stub = Envelope()
            stub.created = datetime.date.today() + datetime.timedelta(2)
            stub._check_expiry_period()

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)
