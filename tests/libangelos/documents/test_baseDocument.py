import uuid
import ipaddress
import os
import random

from unittest import TestCase

from dummy.support import Generate
from libangelos.document.model import (
    BaseDocument, StringField, BinaryField, UuidField, IPField, EmailField, DocumentField)


class TestSubDocument(BaseDocument):
    name = StringField()
    sig = BinaryField()


class TestDocument(BaseDocument):
    id = UuidField()
    ip = IPField()
    email = EmailField()
    docs = DocumentField(doc_class=TestSubDocument)


class TestBaseDocument(TestCase):
    def setUp(self):
        self.instance = TestDocument()

    def tearDown(self):
        del self.instance

    def _populate_test(self):
        data = Generate.person_data()[0]
        sub = TestSubDocument(nd={
            "name": data.given_name+" "+data.family_name,
            "sig": os.urandom(random.randint(20, 30)),
        })

        doc = TestDocument(nd={
            "id": uuid.uuid4(),
            "ip": ipaddress.IPv4Address(os.urandom(4)),
            "email": str(data.given_name+"."+data.family_name+"@example.com").lower(),
            "docs": sub,
        })

        return doc

    def test_build(self):
        try:
            doc = self._populate_test()
            data = doc.export_bytes()
            doc2 = TestDocument.build(data)
        except Exception as e:
            self.fail(e)

    def test_export(self):
        try:
            doc = self._populate_test()
            data = doc.export()
        except Exception as e:
            self.fail(e)

    def test_export_str(self):
        try:
            doc = self._populate_test()
            data = doc.export_str()
        except Exception as e:
            self.fail(e)

    def test_export_bytes(self):
        try:
            doc = self._populate_test()
            data = doc.export_bytes()
        except Exception as e:
            self.fail(e)

    def test_export_yaml(self):
        try:
            doc = self._populate_test()
            ymlstr = doc.export_yaml()
        except Exception as e:
            self.fail(e)

    def test__check_fields(self):
        try:
            doc = self._populate_test()
            doc._check_fields()
        except Exception as e:
            self.fail(e)

    def test_apply_rules(self):
        try:
            doc = self._populate_test()
            self.assertTrue(doc.apply_rules())
        except Exception as e:
            self.fail(e)

    def test_validate(self):
        with self.assertRaises(NotImplementedError) as context:
            doc = self._populate_test()
            doc.validate()
