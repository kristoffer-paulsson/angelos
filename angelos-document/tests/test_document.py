#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
import datetime
import uuid
from unittest import TestCase

from angelos.document.document import IssueMixin, OwnerMixin, UpdatedMixin, Document, DocumentError
from angelos.document.model import BaseDocument, DateField, UuidField


class TestIssueMixin(TestCase):
    def setUp(self):
        self.instance = IssueMixin()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)


class TestOwnerMixin(TestCase):
    def setUp(self):
        self.instance = OwnerMixin()

    def tearDown(self):
        del self.instance

    def test_apply_rules(self):
        try:
            self.assertTrue(self.instance.apply_rules())
        except Exception as e:
            self.fail(e)


class ATestDocument(BaseDocument, IssueMixin, UpdatedMixin):
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
        return ATestDocument(nd={
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

        with self.assertRaises(DocumentError) as context:
            UpdatedMixin.apply_rules(self._populate_doc(1))

    def test__check_updated_latest(self):
        try:
            UpdatedMixin._check_updated_latest(self._populate_doc())
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentError) as context:
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

        with self.assertRaises(DocumentError) as context:
            stub = StubDocument()
            stub.created = datetime.date.today() + datetime.timedelta(1)
            stub._check_expiry_period()

    def test__check_type(self):
        try:
            stub = StubDocument()
            stub._check_doc_type(0)
        except Exception as e:
            self.fail(e)

        with self.assertRaises(DocumentError) as context:
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


    def test___lt__(self):
        try:
            doc1 = StubDocument()
            doc2 = StubDocument()
            doc2.created = datetime.date.today() + datetime.timedelta(1)
            self.assertLess(doc1, doc2)
        except Exception as e:
            self.fail(e)

    def test___le__(self):
        try:
            doc1 = StubDocument()
            doc2 = StubDocument()
            self.assertLessEqual(doc1, doc2)
            doc2.created = datetime.date.today() + datetime.timedelta(1)
            self.assertLessEqual(doc1, doc2)
        except Exception as e:
            self.fail(e)

    def test___gt__(self):
        try:
            doc1 = StubDocument()
            doc2 = StubDocument()
            doc2.created = datetime.date.today() + datetime.timedelta(1)
            self.assertGreater(doc2, doc1)
        except Exception as e:
            self.fail(e)

    def test___ge__(self):
        try:
            doc1 = StubDocument()
            doc2 = StubDocument()
            self.assertGreaterEqual(doc2, doc1)
            doc2.created = datetime.date.today() + datetime.timedelta(1)
            self.assertGreaterEqual(doc2, doc1)
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