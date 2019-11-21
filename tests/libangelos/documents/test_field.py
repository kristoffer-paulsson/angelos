import random
import base64
from unittest import TestCase

from libangelos.error import (
    FieldRequiredNotSet, FieldIsMultiple, FieldNotMultiple, FieldInvalidType, FieldBeyondLimit)
from libangelos.document.model import Field


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

        try:
            instance = self.field(**self.keywords)
            instance.validate(self.type_gen, "test")
        except Exception as e:
            self.fail(e)

        with self.assertRaises(FieldRequiredNotSet) as context:
            instance = self.field(**self.keywords)
            instance.validate(False, "test")

        try:
            instance = self.field(**kw_rec_true)
            instance.validate(self.type_gen, "test")
        except Exception as e:
            self.fail(e)

        with self.assertRaises(FieldRequiredNotSet) as context:
            instance = self.field(**kw_rec_true)
            instance.validate(False, "test")

        try:
            instance = self.field(**kw_rec_false)
            instance.validate(self.type_gen, "test")
        except Exception as e:
            self.fail(e)

        try:
            instance = self.field(**kw_rec_false)
            instance.validate(None, "test")
        except Exception as e:
            self.fail(e)

    def _test_multiple(self):
        kw_multi_true = {**self.keywords, **{"multiple": True}}
        kw_multi_false = {**self.keywords, **{"multiple": False}}
        try:
            instance = self.field(**self.keywords)
            instance.validate(self.type_gen, "test")
        except Exception as e:
            self.fail(e)

        with self.assertRaises(FieldNotMultiple) as context:
            instance = self.field(**self.keywords)
            instance.validate([self.type_gen, self.type_gen], "test")

        try:
            instance = self.field(**kw_multi_true)
            instance.validate([self.type_gen, self.type_gen], "test")
        except Exception as e:
            self.fail(e)

        with self.assertRaises(FieldIsMultiple) as context:
            instance = self.field(**kw_multi_true)
            instance.validate(self.type_gen, "test")

        try:
            instance = self.field(**kw_multi_false)
            instance.validate(self.type_gen, "test")
        except Exception as e:
            self.fail(e)

        with self.assertRaises(FieldNotMultiple) as context:
            instance = self.field(**kw_multi_false)
            instance.validate([self.type_gen, self.type_gen], "test")

    def _test_types(self):
        random.shuffle(self.types)
        for t in self.types:
            if t in self.instance.TYPES:
                try:
                    instance = self.field(**self.keywords)
                    instance.validate(self.gen[t], "test")
                except Exception as e:
                    self.fail(e)
            else:
                with self.assertRaises(FieldInvalidType) as context:
                    instance = self.field(**self.keywords)
                    instance.validate(self.gen[t], "test")

    def _test_limit(self):
        kw_limit = {**self.keywords, **{"limit": 10}}
        try:
            instance = self.field(**kw_limit)
            instance.validate(b'Hello', "test")
        except Exception as e:
            self.fail(e)

        with self.assertRaises(FieldBeyondLimit) as context:
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
