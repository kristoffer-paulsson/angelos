import sys
sys.path.append('../angelos')  # noqa

import unittest
import base64
import datetime
import uuid
import ipaddress

import support
from angelos.document.entities import Person
from angelos.document.document import Document, IssueMixin
from angelos.policy.crypto import Crypto
from angelos.policy.entity import PersonGeneratePolicy, PersonUpdatePolicy


from angelos.document.model import (
    BaseDocument, TypeField, UuidField, IPField, DateField, StringField,
    BinaryField, ChoiceField, EmailField, DocumentField)


class DummySubDocument(BaseDocument):
    bytes = BinaryField()
    string = StringField()


class DummyDocument(Document, IssueMixin):
    type = TypeField(value=1)
    uuid = UuidField()
    ip = IPField()
    date = DateField()
    string = StringField()
    bytes = BinaryField()
    choice = ChoiceField(choices=['yes', 'no'])
    email = EmailField()
    document = DocumentField(t=DummySubDocument)


class TestEntities(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_create_person(self):
        """
        Populating a Person Entity document class with random 'valid' data.
        """
        data = support.random_person_entity_data(1)
        try:
            self.assertIsInstance(Person(nd=data[0]), Person)
        except Exception as e:
            self.fail(e)

    def test_person_generate_policy(self):
        """
        Generating a Person Entity with keys using a GeneratePolicy.
        """
        data = support.random_person_entity_data(1)
        try:
            policy = PersonGeneratePolicy()
            self.assertTrue(policy.generate(**data[0]))
            self.assertTrue(Crypto.verify(
                policy.entity, policy.entity, policy.keys))
            self.assertTrue(Crypto.verify(
                 policy.private, policy.entity, policy.keys))
            self.assertTrue(Crypto.verify(
                policy.keys, policy.entity, policy.keys))
        except Exception as e:
            self.fail(e)

    def test_sign_verify(self):
        try:
            data = support.random_person_entity_data(1)
            policy = PersonGeneratePolicy()
            policy.generate(**data[0])

            d = DummyDocument()
            d.issuer = policy.entity.id
            d.type = 100
            d.uuid = uuid.UUID(bytes=b'\x12\x34\x56\x78'*4)
            d.ip = ipaddress.IPv4Address('127.0.0.1')
            d.date = datetime.date(1970, 1, 1)
            d.string = 'Hello, world!'
            d.bytes = base64.standard_b64encode(b'1234567890')
            d.choice = 'no'
            d.email = 'john.doe@example.com'
            d.document = DummySubDocument(
                nd={'bytes': b'Hello', 'string': 'world'})

            d2 = Crypto.sign(d, policy.entity, policy.private, policy.keys)
            self.assertIsInstance(d2, DummyDocument)
            self.assertTrue(Crypto.verify(d2, policy.entity, policy.keys))
        except Exception as e:
            self.fail(e)

    def test_person_change(self):
        """
        Update a Person using a UpdatePolicy.
        """
        data = support.random_person_entity_data(1)
        try:
            gpolicy = PersonGeneratePolicy()
            gpolicy.generate(**data[0])
            Crypto.verify(gpolicy.entity, gpolicy.entity, gpolicy.keys)
            upolicy = PersonUpdatePolicy()

            self.assertRaises(
                IndexError, upolicy.change, gpolicy.entity,
                family_name='Doe', surname='Doe')
            entity = upolicy.change(gpolicy.entity, family_name='Doe')
            self.assertEqual(entity.family_name, 'Doe')
        except Exception as e:
            self.fail(e)

    def test_person_update(self):
        """
        Update a Person using a UpdatePolicy.
        """
        data = support.random_person_entity_data(1)
        try:
            gpolicy = PersonGeneratePolicy()
            gpolicy.generate(**data[0])
            Crypto.verify(gpolicy.entity, gpolicy.entity, gpolicy.keys)
            upolicy = PersonUpdatePolicy()

            self.assertTrue(upolicy.update(
                gpolicy.entity, gpolicy.private, gpolicy.keys))
            self.assertTrue(Crypto.verify(
                upolicy.entity, gpolicy.entity, gpolicy.keys))
        except Exception as e:
            self.fail(e)

    def test_person_newkeys(self):
        """
        Update a Person using a UpdatePolicy.
        """
        data = support.random_person_entity_data(1)
        try:
            gpolicy = PersonGeneratePolicy()
            gpolicy.generate(**data[0])
            Crypto.verify(gpolicy.entity, gpolicy.entity, gpolicy.keys)
            upolicy = PersonUpdatePolicy()

            upolicy.newkeys(
                gpolicy.entity, gpolicy.private, gpolicy.keys)

            self.assertTrue(Crypto.verify(
                upolicy.private, gpolicy.entity, gpolicy.keys))

            self.assertTrue(Crypto.verify(
                upolicy.keys, gpolicy.entity, gpolicy.keys))
            self.assertTrue(Crypto.verify(
                upolicy.keys, gpolicy.entity, upolicy.keys))
        except Exception as e:
            self.fail(e)

    def test_person_change_updatenewkeys(self):
        """
        Update a Person using a UpdatePolicy.
        """
        data = support.random_person_entity_data(1)
        try:
            gpolicy = PersonGeneratePolicy()
            gpolicy.generate(**data[0])
            Crypto.verify(gpolicy.entity, gpolicy.entity, gpolicy.keys)
            upolicy = PersonUpdatePolicy()

            entity = upolicy.change(gpolicy.entity, family_name='Doe')
            upolicy.update(entity, gpolicy.private, gpolicy.keys)
            upolicy.newkeys(entity, gpolicy.private, gpolicy.keys)

            self.assertEqual(entity.family_name, 'Doe')
            self.assertTrue(Crypto.verify(entity, entity, gpolicy.keys))

            self.assertTrue(Crypto.verify(
                upolicy.private, entity, gpolicy.keys))

            self.assertTrue(Crypto.verify(
                upolicy.keys, gpolicy.entity, gpolicy.keys))
            self.assertTrue(Crypto.verify(
                upolicy.keys, gpolicy.entity, upolicy.keys))
        except Exception as e:
            self.fail(e)


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
