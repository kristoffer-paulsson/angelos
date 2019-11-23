import datetime
import uuid

from unittest import TestCase

from libangelos.error import DocumentShortExpiry, DocumentUpdatedNotLatest
from libangelos.document.model import BaseDocument, DateField
from libangelos.document.document import UpdatedMixin, IssueMixin


class TestDocument(BaseDocument, IssueMixin, UpdatedMixin):
    """Simulates fields: signature, issuer, updated, expires."""
    created = DateField()
    expires = DateField(
        init=lambda: (
            datetime.date.today() + datetime.timedelta(13 * 365 / 12)
        )
    )


class TestUpdatedMixin(TestCase):
    def setUp(self):
        self.instance = UpdatedMixin()

    def tearDown(self):
        del self.instance

    def _populate_doc(self, days=0):
        return TestDocument(nd={
                "created": datetime.date.today(),
                "updated": datetime.date.today() + datetime.timedelta(days),
                "signature": b"Hello, world!",
                "issuer": uuid.uuid4()
            })

    def test_apply_rules(self):
        self.assertEqual(
            UpdatedMixin.apply_rules(self._populate_doc()), True)

    def test__check_expiry_period(self):
        try:
            UpdatedMixin._check_expiry_period(self._populate_doc())
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentShortExpiry) as context:
            UpdatedMixin.apply_rules(self._populate_doc(1))

    def test__check_updated_latest(self):
        try:
            UpdatedMixin._check_updated_latest(self._populate_doc())
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentUpdatedNotLatest) as context:
            doc = self._populate_doc()
            doc.updated = datetime.date.today() + datetime.timedelta(-2)
            UpdatedMixin._check_updated_latest(doc)

    def test_renew(self):
        try:
            doc = self._populate_doc()
            doc.renew()
            doc.signature = None

            today = datetime.date.today()
            self.assertEqual(doc.updated, today)
            self.assertEqual(doc.expires, today + datetime.timedelta(13 * 365 / 12))
            self.assertIs(doc.signature, None)

        except Exception as e:
            self.fail(e)
