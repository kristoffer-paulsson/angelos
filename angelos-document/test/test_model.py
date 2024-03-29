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
import base64
import copy
import datetime
import ipaddress
import os
import random
import uuid
from unittest import TestCase

from angelos.document.model import Field, UuidField, BaseDocument, DocumentField, IPField, DateField, DateTimeField, \
    TypeField, BinaryField, SignatureField, StringField, ChoiceField, RegexField, EmailField, DocumentMeta, FieldError

from test.fixture.generate import Generate


class BaseTestField(TestCase):
    instance = None
    field = None
    keywords = dict()
    type = None
    type_gen = True

    types = [  # Don't use list, it interferes with other tests.
        bool,
        int,
        float,
        bytes,
        bytearray,
        str,
        tuple,
        dict,
        set,
        object
    ]

    gen = {
        bool: True,
        int: 865,
        float: 436.23465,
        bytes: b'sdfdfhrtgsfsfcvbhweqqqdsxcferergerggcrtrf',
        bytearray: bytearray(b'sdfhjikjnvfewew23dr5tygbhj8iygvddertyjjjsqae'),
        str: "Hello, world!",
        tuple: ('e', 'w', 'z', 'd', 's', '5'),
        dict: {'foo': "bar"},
        set: set(['4', 'd', 'x', 'k', 'y', 'n']),
        object: object()
    }

    def setUp(self):
        self.instance = self.field()
        self.types.append(self.type)
        self.gen[self.type] = self.type_gen

    def tearDown(self):
        del self.instance

    def _test_required(self):
        kw_rec_true = {**self.keywords, **{"required": True}}
        kw_rec_false = {**self.keywords, **{"required": False}}

        instance = self.field(**self.keywords)
        instance.validate(self.type_gen, "test")

        with self.assertRaises(FieldError) as context:
            instance = self.field(**self.keywords)
            instance.validate(False, "test")

        instance = self.field(**kw_rec_true)
        instance.validate(self.type_gen, "test")

        with self.assertRaises(FieldError) as context:
            instance = self.field(**kw_rec_true)
            instance.validate(False, "test")

        instance = self.field(**kw_rec_false)
        instance.validate(self.type_gen, "test")

        instance = self.field(**kw_rec_false)
        instance.validate(None, "test")

    def _test_multiple(self):
        kw_multi_true = {**self.keywords, **{"multiple": True}}
        kw_multi_false = {**self.keywords, **{"multiple": False}}

        instance = self.field(**self.keywords)
        instance.validate(self.type_gen, "test")

        with self.assertRaises(FieldError) as context:
            instance = self.field(**self.keywords)
            instance.validate([self.type_gen, self.type_gen], "test")

        instance = self.field(**kw_multi_true)
        instance.validate([self.type_gen, self.type_gen], "test")

        with self.assertRaises(FieldError) as context:
            instance = self.field(**kw_multi_true)
            instance.validate(self.type_gen, "test")

        instance = self.field(**kw_multi_false)
        instance.validate(self.type_gen, "test")

        with self.assertRaises(FieldError) as context:
            instance = self.field(**kw_multi_false)
            instance.validate([self.type_gen, self.type_gen], "test")

    def _test_types(self):
        random.shuffle(self.types)
        for t in self.types:
            if t in self.instance.TYPES:
                instance = self.field(**self.keywords)
                instance.validate(self.gen[t], "test")
            else:
                with self.assertRaises(FieldError) as context:
                    instance = self.field(**self.keywords)
                    instance.validate(self.gen[t], "test")

    def _test_limit(self):
        kw_limit = {**self.keywords, **{"limit": 10}}
        instance = self.field(**kw_limit)
        instance.validate(b'Hello', "test")

        with self.assertRaises(FieldError) as context:
            instance = self.field(**kw_limit)
            instance.validate(b'Hello, world!', "test")

    def _test_bytes_wint(self):
        instance = self.field(**self.keywords)
        serialized = instance.bytes(self.type_gen)
        value = instance.from_bytes(serialized)
        self.assertEqual(int(self.type_gen), int(value))

    def _test_bytes_wstr(self):
        instance = self.field(**self.keywords)
        serialized = instance.bytes(self.type_gen)
        value = instance.from_bytes(serialized)
        self.assertIn(str(self.type_gen), str(value))

    def _test_str(self):
        instance = self.field(**self.keywords)
        value = instance.str(self.type_gen)
        self.assertIn(value, str(self.type_gen))

    def _test_str_wb64(self):
        instance = self.field(**self.keywords)
        value = instance.str(self.type_gen)
        self.assertIn(value, base64.standard_b64encode(self.type_gen).decode("utf-8"))

    def _test_str_wbytes(self):
        instance = self.field(**self.keywords)
        value = instance.str(self.type_gen)
        value2 = instance.bytes(self.type_gen)
        self.assertIn(value, value2.decode())

    def _test_yaml(self):
        instance = self.field(**self.keywords)
        value = instance.yaml(self.type_gen)
        self.assertIs(value.__class__, str)
        self.assertNotRegex(value, r"(\\x[0-9a-fA-F].)")


class TestField(BaseTestField):
    field = Field
    type = bool
    type_gen = True

    def test_validate(self):
        self._test_required()
        self._test_multiple()

    def test_from_bytes(self):
        with self.assertRaises(NotImplementedError) as context:
            self.instance.from_bytes(b' ')

    def test_str(self):
        with self.assertRaises(NotImplementedError) as context:
            self.instance.str(object())

    def test_bytes(self):
        with self.assertRaises(NotImplementedError) as context:
            self.instance.str(object())

    def test_yaml(self):
        with self.assertRaises(NotImplementedError) as context:
            self.instance.yaml(object())


class TestDocumentMeta(TestCase):
    def setUp(self):
        self.instance = DocumentMeta()

    def tearDown(self):
        del self.instance


class TestSubDocument(BaseDocument):
    name = StringField()
    sig = BinaryField()


class TestDocument(BaseDocument):
    id = UuidField()
    ip = IPField()
    email = EmailField()
    docs = DocumentField(doc_class=TestSubDocument)


class TestDocument2(BaseDocument):
    id = UuidField(init=uuid.uuid4)


class TestBaseDocument(TestCase):
    def setUp(self):
        self.instance = TestDocument()

    def tearDown(self):
        del self.instance

    def _populate_test(self):
        data = Generate.person_data()[0]
        sub = TestSubDocument(nd={
            "name": data["given_name"] + " " + data["family_name"],
            "sig": os.urandom(random.randint(20, 30)),
        })

        doc = TestDocument(nd={
            "id": uuid.uuid4(),
            "ip": ipaddress.IPv4Address(os.urandom(4)),
            "email": str(data["given_name"] + "." + data["family_name"] + "@example.com").lower(),
            "docs": sub,
        })

        return doc

    def test_build(self):
        doc = self._populate_test()
        data = doc.export_bytes()
        doc2 = TestDocument.build(data)

    def test_export(self):
        doc = self._populate_test()
        data = doc.export()

    def test_export_str(self):
        doc = self._populate_test()
        data = doc.export_str()

    def test_export_bytes(self):
        doc = self._populate_test()
        data = doc.export_bytes()

    def test_export_yaml(self):
        doc = self._populate_test()
        ymlstr = doc.export_yaml()

    def test__check_fields(self):
        doc = self._populate_test()
        doc._check_fields()

    def test_apply_rules(self):
        doc = self._populate_test()
        self.assertTrue(doc.apply_rules())

    def test_validate(self):
        with self.assertRaises(NotImplementedError) as context:
            doc = self._populate_test()
            doc.validate()

    def test___eq__(self):
        doc = self._populate_test()
        self.assertFalse(doc == True)
        self.assertFalse(doc is True)

        my_copy = TestDocument2()
        self.assertFalse(doc == my_copy)
        self.assertFalse(doc is my_copy)

        my_copy = doc
        self.assertTrue(doc == my_copy)
        self.assertTrue(doc is my_copy)

        my_copy = copy.copy(doc)
        self.assertTrue(doc == my_copy)
        self.assertFalse(doc is my_copy)

        my_copy = copy.deepcopy(doc)
        self.assertTrue(doc == my_copy)
        self.assertFalse(doc is my_copy)

        my_copy = copy.deepcopy(doc)
        my_copy.email = "john.doe@example.com"
        self.assertFalse(doc == my_copy)
        self.assertFalse(doc is my_copy)


class TestDocumentField(BaseTestField):
    field = DocumentField
    type = TestDocument2
    type_gen = TestDocument2()

    def _test_types(self):
        # DocumentField use custom type handling!
        random.shuffle(self.types)
        for t in self.types:
            if t == self.type:
                instance = self.field()
                instance.validate(self.gen[t], "test")
            else:
                with self.assertRaises(FieldError) as context:
                    instance = self.field()
                    instance.validate(self.gen[t], "test")

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        serialized = self.type().export_bytes()
        instance = self.field(doc_class=TestDocument2)
        self.assertIsInstance(
            instance.from_bytes(serialized),
            self.type,
            "Could not restore document from bytes")


class TestUuidField(BaseTestField):
    field = UuidField
    type = uuid.UUID
    type_gen = uuid.uuid4()

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        self._test_bytes_wint()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wint()

    def test_yaml(self):
        self._test_yaml()


class TestIPField(BaseTestField):
    field = IPField
    type = ipaddress.IPv4Address
    type_gen = ipaddress.IPv4Address('192.168.0.1')

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        self._test_bytes_wint()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wint()

    def test_yaml(self):
        self._test_yaml()


class TestDateField(BaseTestField):
    field = DateField
    type = datetime.date
    type_gen = datetime.date.today()

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()


class TestDateTimeField(BaseTestField):
    field = DateTimeField
    type = datetime.datetime
    type_gen = datetime.datetime.now()

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str_wbytes()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()


class TestTypeField(BaseTestField):
    field = TypeField
    type = int
    type_gen = 143

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        self._test_bytes_wint()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wint()

    def test_yaml(self):
        self._test_yaml()


class TestBinaryField(BaseTestField):
    field = BinaryField
    type = bytes
    type_gen = b'6\xa9\xa1P\xd8\xd5H\x17\xa2P\x13\xff\xebv\x934'

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()
        self._test_limit()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str_wb64()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()


class TestSignatureField(BaseTestField):
    field = SignatureField
    type = bytes
    type_gen = b'6\xa9\xa1P\xd8\xd5H\x17\xa2P\x13\xff\xebv\x934'

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()
        self._test_limit()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str_wb64()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()


class TestStringField(BaseTestField):
    field = StringField
    type = str
    type_gen = "Hello, world!"

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()


class TestChoiceField(BaseTestField):
    field = ChoiceField
    keywords = {
        "choices": ["banana", "apple", "orange"]
    }
    type = str
    type_gen = "orange"

    def _test_choices(self):
        choices = self.keywords["choices"] + ["grape", "pear", "pineapple"]
        random.shuffle(choices)
        for c in choices:
            if c in self.keywords["choices"]:
                instance = self.field(**self.keywords)
                instance.validate(c, "test")
            else:
                with self.assertRaises(FieldError) as context:
                    instance = self.field(**self.keywords)
                    instance.validate(c, "test")

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()
        self._test_choices()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()


class TestRegexField(BaseTestField):
    field = RegexField
    type = str
    type_gen = "Hello, world!"

    regex_success = list()
    regex_failure = list()

    def _test_regex(self):
        for s in self.regex_success:
            instance = self.field(**self.keywords)
            instance.validate(s, "test")
        for f in self.regex_failure:
            with self.assertRaises(FieldError) as context:
                instance = self.field(**self.keywords)
                instance.validate(f, "test")

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()
        self._test_regex()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()


class TestEmailField(TestRegexField):
    field = EmailField
    type = str
    type_gen = "john.doe@example.com"

    regex_success = [
        "email@example.com",
        "firstname.lastname@example.com",
        "email@subdomain.example.com",
        "firstname+lastname@example.com",
        "email@123.123.123.123",
        "email@[123.123.123.123]",
        "\"email\"@example.com",
        "1234567890@example.com",
        "email@example-one.com",
        "_______@example.com",
        "email@example.name",
        "email@example.museum",
        "email@example.co.jp",
        "firstname-lastname@example.com",
    ]
    regex_failure = [
        "plainaddress",
        "#@%^%#$@#$@#.com",
        "@example.com",
        "Joe Smith <email@example.com>",
        "email.example.com",
        "email@example@example.com",
        ".email@example.com",
        "email.@example.com",
        "email..email@example.com",
        "@example.com",
        "email@example.com (Joe Smith)",
        "email@example",
        "email@-example.com",
        # "email@example.web",  # Motivated failure
        # "email@111.222.333.44444",  # Unmotivated failure
        "email@example..com",
        "Abc..123@example.com"
    ]

    def test_validate(self):
        self._test_required()
        self._test_multiple()
        self._test_types()
        self._test_regex()

    def test_from_bytes(self):
        self._test_bytes_wstr()

    def test_str(self):
        self._test_str()

    def test_bytes(self):
        self._test_bytes_wstr()

    def test_yaml(self):
        self._test_yaml()
