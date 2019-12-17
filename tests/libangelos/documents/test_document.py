import datetime
import uuid
from unittest import TestCase

from libangelos.document.document import Document, UpdatedMixin, OwnerMixin
from libangelos.document.model import UuidField
from libangelos.error import DocumentShortExpiry, DocumentInvalidType


class StubDocument(Document):
    id = UuidField(init=uuid.uuid4)


class StubDocumentUpdated(Document, UpdatedMixin):
    id = UuidField(init=uuid.uuid4)


class StubDocumentOwner(Document, OwnerMixin):
    id = UuidField(init=uuid.uuid4)


class TestDocument(TestCase):
    def test__check_expiry_period(self):
        try:
            stub = StubDocument()
            stub._check_expiry_period()
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentShortExpiry) as context:
            stub = StubDocument()
            stub.created = datetime.date.today() + datetime.timedelta(1)
            stub._check_expiry_period()

    def test__check_type(self):
        try:
            stub = StubDocument()
            stub._check_doc_type(0)
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentInvalidType) as context:
            stub = StubDocument()
            stub._check_doc_type(1)

    def test_get_touched(self):
        try:
            stub = StubDocumentUpdated()
            self.assertIs(stub.get_touched(), stub.created)
            stub.updated = datetime.date.today() + datetime.timedelta(1)
            self.assertIs(stub.get_touched(), stub.updated)
        except Exception as e:
            self.fail(e)

    def test_get_owner(self):
        try:
            stub = StubDocument()
            self.assertIs(stub.get_owner(), stub.issuer)

            stub = StubDocumentOwner()
            self.assertIs(stub.get_owner(), stub.owner)
        except Exception as e:
            self.fail(e)

    def test_apply_rules(self):
        try:
            stub = StubDocument()
            self.assertTrue(stub.apply_rules())
        except Exception as e:
            self.fail(e)

    def test_validate(self):
        try:
            stub = StubDocument(nd={
                "signature": b"crypto_signature",
                "issuer": uuid.uuid4(),
                "type": 1
            })
            self.assertTrue(stub.validate())
        except Exception as e:
            self.fail(e)

    def test_is_expired(self):
        try:
            stub = StubDocument()
            self.assertFalse(stub.is_expired())
            stub.expires = datetime.date.today() + datetime.timedelta(-2)
            self.assertTrue(stub.is_expired())
        except Exception as e:
            self.fail(e)

    def test_expires_soon(self):
        try:
            stub = StubDocument()
            self.assertFalse(stub.expires_soon())

            stub.expires = datetime.date.today() + datetime.timedelta(15)
            self.assertTrue(stub.expires_soon())

            stub.expires = datetime.date.today() + datetime.timedelta(-2)
            self.assertFalse(stub.expires_soon())
        except Exception as e:
            self.fail(e)
