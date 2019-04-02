import sys
sys.path.append('../angelos')  # noqa

import unittest
import uuid
import ipaddress
import datetime
import base64

import angelos.error as error
from angelos.document.model import (
    BaseDocument, Field, TypeField, UuidField, IPField, DateField, StringField,
    BinaryField, ChoiceField, EmailField, DocumentField, conv_str, conv_bytes)


class DummySubDocument(BaseDocument):
    bytes = BinaryField()
    string = StringField()


class DummyDocument(BaseDocument):
    type = TypeField(value=1)
    uuid = UuidField()
    ip = IPField()
    date = DateField()
    string = StringField()
    bytes = BinaryField()
    choice = ChoiceField(choices=['yes', 'no'])
    email = EmailField()
    document = DocumentField(t=DummySubDocument)


class DummyTypeField(BaseDocument):
    field = TypeField(required=False)


class DummyUuidField(BaseDocument):
    field = UuidField(required=False)


class DummyIPField(BaseDocument):
    field = IPField(required=False)


class DummyDateField(BaseDocument):
    field = DateField(required=False)


class DummyStringField(BaseDocument):
    field = StringField(required=False)


class DummyBinaryField(BaseDocument):
    field = BinaryField(required=False, limit=15)


class DummyChoiceField(BaseDocument):
    field = ChoiceField(required=False, choices=['yes', 'no'])


class DummyEmailField(BaseDocument):
    field = EmailField(required=False)


class DummyDocumentField(BaseDocument):
    field = DocumentField(required=False, t=DummySubDocument)


class TestModel(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        pass

    @classmethod
    def tearDownClass(cls):
        pass

    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_field(self):
        """Isolated test of the Field class"""
        # Test required with no value
        f = Field()
        self.assertRaises(error.FieldRequiredNotSet, f.validate, f.value)
        # Test not required with no value
        f = Field(required=False)
        self.assertTrue(f.validate(f.value))
        # Test required with value
        f = Field(value=1)
        self.assertTrue(f.validate(f.value))
        # Test multiple
        f = Field(multiple=True, value=1)
        self.assertRaises(error.FieldIsMultiple, f.validate, f.value)

    def test_typefield(self):
        """Test of the TypeField class"""
        self.assertTrue(DummyTypeField(nd={'field': 1})._validate())
        self.assertTrue(DummyTypeField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyTypeField(
                nd={'field': 'str'}))

        self.assertIsInstance(
            DummyTypeField(nd={'field': 1}).export(conv_str)['field'], str)
        self.assertEqual(
            DummyTypeField(nd={'field': 1}).export(conv_str)['field'], '1')

        self.assertIsInstance(
            DummyTypeField(nd={'field': 1}).export(
                conv_bytes)['field'], bytes)
        self.assertEqual(
            DummyTypeField(nd={'field': 1}).export(
                conv_bytes)['field'], b'\01')

    def test_uuidfield(self):
        """Test of the UuidField class"""
        self.assertTrue(DummyUuidField(nd={'field': uuid.uuid4()})._validate())
        self.assertTrue(DummyUuidField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyUuidField(
                nd={'field': 'str'}))

        self.assertIsInstance(
            DummyUuidField(nd={'field': uuid.uuid4()}).export(
                conv_str)['field'], str)

        self.assertIsInstance(
            DummyUuidField(nd={'field': uuid.uuid4()}).export(
                conv_bytes)['field'], bytes)

    def test_ipfield(self):
        """Test of the IPField class"""
        self.assertTrue(DummyIPField(
            nd={'field': ipaddress.IPv4Address('127.0.0.1')})._validate())
        self.assertTrue(DummyIPField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyIPField(
                nd={'field': 'str'}))

        self.assertIsInstance(
            DummyIPField(nd={'field': ipaddress.IPv4Address(
                '127.0.0.1')}).export(conv_str)['field'], str)

        self.assertIsInstance(
            DummyIPField(nd={'field': ipaddress.IPv4Address(
                '127.0.0.1')}).export(conv_bytes)['field'], bytes)

        self.assertIsInstance(
            DummyIPField(nd={'field': ipaddress.IPv6Address(
                '::1')}).export(conv_str)['field'], str)

        self.assertIsInstance(
            DummyIPField(nd={'field': ipaddress.IPv6Address(
                '::1')}).export(conv_bytes)['field'], bytes)

    def test_datefield(self):
        """Test of the DateField class"""
        self.assertTrue(DummyDateField(
            nd={'field': datetime.date.today()})._validate())
        self.assertTrue(DummyDateField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyDateField(
                nd={'field': 'str'}))

        self.assertIsInstance(DummyDateField(nd={'field': datetime.date(
            1970, 1, 1)}).export(conv_str)['field'], str)
        self.assertEqual(DummyDateField(nd={'field': datetime.date(
            1970, 1, 1)}).export(conv_str)['field'], '1970-01-01')

        self.assertIsInstance(DummyDateField(nd={'field': datetime.date(
            1970, 1, 1)}).export(conv_bytes)['field'], bytes)
        self.assertEqual(DummyDateField(nd={'field': datetime.date(
            1970, 1, 1)}).export(conv_bytes)['field'], b'1970-01-01')

    def test_stringfield(self):
        """Test of the StringField class"""
        self.assertTrue(DummyStringField(
            nd={'field': 'Hello, world!'})._validate())
        self.assertTrue(DummyStringField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyStringField(
                nd={'field': 123}))

        self.assertIsInstance(DummyStringField(
            nd={'field':  'Hello, world!'}).export(conv_str)['field'], str)
        self.assertEqual(DummyStringField(
            nd={'field': 'Hello, world!'}).export(
                conv_str)['field'], 'Hello, world!')

        self.assertIsInstance(DummyStringField(
            nd={'field': 'Hello, world!'}).export(conv_bytes)['field'], bytes)
        self.assertEqual(DummyStringField(
            nd={'field': 'Hello, world!'}).export(
                conv_bytes)['field'], b'Hello, world!')

    def test_BinaryField(self):
        """Test of the BinaryField class"""
        self.assertTrue(DummyBinaryField(
            nd={'field': b'Hello, world!'})._validate())
        self.assertTrue(DummyBinaryField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyBinaryField(
                nd={'field': 'str'}))
        self.assertRaises(
            error.FieldBeyondLimit, lambda: DummyBinaryField(
                nd={'field': b'Hello, world! 123'}))

        self.assertIsInstance(DummyBinaryField(
            nd={'field':  b'Hello, world!'}).export(conv_str)['field'], str)
        self.assertEqual(DummyBinaryField(
            nd={'field': b'Hello, world!'}).export(
                conv_str)['field'], 'SGVsbG8sIHdvcmxkIQ==')

        self.assertIsInstance(DummyBinaryField(
            nd={'field': b'Hello, world!'}).export(conv_bytes)['field'], bytes)
        self.assertEqual(DummyBinaryField(
            nd={'field': b'Hello, world!'}).export(
                conv_bytes)['field'], b'Hello, world!')

    def test_choicefield(self):
        """Test of the ChoiceField class"""
        self.assertTrue(DummyChoiceField(nd={'field': 'yes'})._validate())
        self.assertTrue(DummyChoiceField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidChoice, lambda: DummyChoiceField(
                nd={'field': 123}))
        self.assertRaises(
            error.FieldInvalidChoice, lambda: DummyChoiceField(
                nd={'field': 'maybe'}))

        self.assertIsInstance(DummyChoiceField(
            nd={'field':  'yes'}).export(conv_str)['field'], str)
        self.assertEqual(DummyChoiceField(
            nd={'field': 'yes'}).export(
                conv_str)['field'], 'yes')

        self.assertIsInstance(DummyChoiceField(
            nd={'field': 'yes'}).export(conv_bytes)['field'], bytes)
        self.assertEqual(DummyChoiceField(
            nd={'field': 'yes'}).export(
                conv_bytes)['field'], b'yes')

    def test_emailfield(self):
        """Test of the EmailField class"""
        self.assertTrue(DummyEmailField(
            nd={'field': 'john.doe@example.com'})._validate())
        self.assertTrue(DummyEmailField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyEmailField(
                nd={'field': b'str'}))
        self.assertRaises(
            error.FieldInvalidEmail, lambda: DummyEmailField(
                nd={'field': 'john.doe[at]example.com'}))

        self.assertIsInstance(DummyEmailField(
            nd={'field':  'john.doe@example.com'}).export(
                conv_str)['field'], str)
        self.assertEqual(DummyEmailField(
            nd={'field': 'john.doe@example.com'}).export(
                conv_str)['field'], 'john.doe@example.com')

        self.assertIsInstance(DummyEmailField(
            nd={'field': 'john.doe@example.com'}).export(
                conv_bytes)['field'], bytes)
        self.assertEqual(DummyEmailField(
            nd={'field': 'john.doe@example.com'}).export(
                conv_bytes)['field'], b'john.doe@example.com')

    def test_documentfield(self):
        """Test of the DocumentField class"""
        self.assertTrue(DummyDocumentField(
            nd={'field': DummySubDocument(
                nd={'bytes': b'Hello', 'string': 'world'})})._validate())
        self.assertTrue(DummyDocumentField(nd={})._validate())
        self.assertRaises(
            error.FieldInvalidType, lambda: DummyDocumentField(
                nd={'field': 'str'}))

        d = DummyDocument()
        d.type = 100
        d.uuid = uuid.UUID(bytes=b'\x12\x34\x56\x78'*4)
        d.ip = ipaddress.IPv4Address('127.0.0.1')
        d.date = datetime.date(1970, 1, 1)
        d.string = 'Hello, world!'
        d.bytes = b'1234567890'
        d.choice = 'no'
        d.email = 'john.doe@example.com'
        d.document = DummySubDocument(
            nd={'bytes': b'Hello', 'string': 'world'})

        strobj = d.export(conv_str)
        self.assertEqual(strobj['type'], '100')
        self.assertEqual(strobj['uuid'],
                         '12345678-1234-5678-1234-567812345678')
        self.assertEqual(strobj['ip'], '127.0.0.1')
        self.assertEqual(strobj['date'], '1970-01-01')
        self.assertEqual(strobj['string'], 'Hello, world!')
        self.assertEqual(strobj['bytes'], 'MTIzNDU2Nzg5MA==')
        self.assertEqual(strobj['choice'], 'no')
        self.assertEqual(strobj['email'], 'john.doe@example.com')
        self.assertEqual(strobj['document']['bytes'], 'SGVsbG8=')
        self.assertEqual(strobj['document']['string'], 'world')

        bytesobj = d.export(conv_bytes)
        self.assertEqual(bytesobj['type'], b'd')
        self.assertEqual(bytesobj['uuid'], b'\x124Vx\x124Vx\x124Vx\x124Vx')
        self.assertEqual(bytesobj['ip'], b'\x7f\x00\x00\x01')
        self.assertEqual(bytesobj['date'], b'1970-01-01')
        self.assertEqual(bytesobj['string'], b'Hello, world!')
        self.assertEqual(bytesobj['bytes'], b'1234567890')
        self.assertEqual(bytesobj['choice'], b'no')
        self.assertEqual(bytesobj['email'], b'john.doe@example.com')
        self.assertEqual(bytesobj['document']['bytes'], b'Hello')
        self.assertEqual(bytesobj['document']['string'], b'world')


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
