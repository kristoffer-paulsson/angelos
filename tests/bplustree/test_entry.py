#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import os
import uuid
from unittest import TestCase

from bplustree.const import OTHERS_BYTES
from bplustree.entry import Entry, TreeConf, Record, Reference, OpaqueData
from bplustree.serializer import UUIDSerializer


def tree_conf(page_size, order, key_size, value_size, serializer=None):
    return TreeConf(
        page_size, order, key_size, value_size, OTHERS_BYTES,
        serializer or UUIDSerializer()
    )


class TestEntry(TestCase):
    def test_load(self):
        try:
            with self.assertRaises(TypeError):
                Entry()
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            with self.assertRaises(TypeError):
                Entry()
        except Exception as e:
            self.fail(e)


class TestComparableEntry(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.k1 = uuid.UUID(int=1)
        self.k2 = uuid.UUID(int=1)
        self.k3 = uuid.UUID(int=2)

    def test___eq__(self):
        try:
            r1 = Record(self.conf, self.k1)
            r2 = Record(self.conf, self.k2)
            r3 = Record(self.conf, self.k3)
            self.assertTrue(r1 == r2)
            self.assertFalse(r1 == r3)
            self.assertFalse(r2 == r3)
        except Exception as e:
            self.fail(e)

    def test___lt__(self):
        try:
            r1 = Record(self.conf, self.k1)
            r2 = Record(self.conf, self.k2)
            r3 = Record(self.conf, self.k3)
            self.assertFalse(r1 < r2)
            self.assertTrue(r1 < r3)
            self.assertTrue(r2 < r3)
            self.assertFalse(r2 < r1)
            self.assertFalse(r3 < r1)
            self.assertFalse(r3 < r2)
        except Exception as e:
            self.fail(e)

    def test___le__(self):
        try:
            r1 = Record(self.conf, self.k1)
            r2 = Record(self.conf, self.k2)
            r3 = Record(self.conf, self.k3)
            self.assertTrue(r1 <= r2)
            self.assertTrue(r1 <= r3)
            self.assertTrue(r2 <= r3)
            self.assertTrue(r2 <= r1)
            self.assertFalse(r3 <= r1)
            self.assertFalse(r3 <= r2)
        except Exception as e:
            self.fail(e)

    def test___gt__(self):
        try:
            r1 = Record(self.conf, self.k1)
            r2 = Record(self.conf, self.k2)
            r3 = Record(self.conf, self.k3)
            self.assertFalse(r1 > r2)
            self.assertFalse(r1 > r3)
            self.assertFalse(r2 > r3)
            self.assertFalse(r2 > r1)
            self.assertTrue(r3 > r1)
            self.assertTrue(r3 > r2)
        except Exception as e:
            self.fail(e)

    def test___ge__(self):
        try:
            r1 = Record(self.conf, self.k1)
            r2 = Record(self.conf, self.k2)
            r3 = Record(self.conf, self.k3)
            self.assertTrue(r1 >= r2)
            self.assertFalse(r1 >= r3)
            self.assertFalse(r2 >= r3)
            self.assertTrue(r2 >= r1)
            self.assertTrue(r3 >= r1)
            self.assertTrue(r3 >= r2)
        except Exception as e:
            self.fail(e)


class TestRecord(TestCase):

    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.key = uuid.uuid4()
        self.value = os.urandom(32)
        self.value_overflow = os.urandom(48)

    def test_key(self):
        try:
            record = Record(self.conf, self.key, self.value)
            self.assertEqual(record.key, self.key)
            key = uuid.uuid4()
            record.key = key
            self.assertEqual(record.key, key)
            self.assertIn(key.bytes, record.dump())
        except Exception as e:
            self.fail(e)

    def test_value(self):
        try:
            record = Record(self.conf, self.key, self.value)
            self.assertEqual(record.value, self.value)
            value = os.urandom(32)
            record.value = value
            self.assertEqual(record.value, value)
            self.assertIn(value, record.dump())
        except Exception as e:
            self.fail(e)

    def test_overflow_page(self):
        try:
            record = Record(self.conf, self.key, self.value)
            self.assertEqual(record.overflow_page, None)
            record.overflow_page = 123
            self.assertEqual(record.overflow_page, 123)
        except Exception as e:
            self.fail(e)

    def test_load(self):
        try:
            record = Record(self.conf, self.key, self.value)
            data = record.dump()
            new_record = Record(self.conf)
            new_record.load(data)
            self.assertEqual(record.key, new_record.key)
            self.assertEqual(record.value, new_record.value)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            record = Record(self.conf, self.key, self.value)
            data = record.dump()
            new_record = Record(self.conf, data=data)
            self.assertEqual(record.key, new_record.key)
            self.assertEqual(record.value, new_record.value)
        except Exception as e:
            self.fail(e)


class TestReference(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.key = uuid.uuid4()
        self.before = 11
        self.after = 143

    def test_key(self):
        try:
            record = Reference(self.conf, self.key, self.before, self.after)
            self.assertEqual(record.key, self.key)
            key = uuid.uuid4()
            record.key = key
            self.assertEqual(record.key, key)
            self.assertIn(key.bytes, record.dump())
        except Exception as e:
            self.fail(e)

    def test_before(self):
        try:
            record = Reference(self.conf, self.key, self.before, self.after)
            self.assertEqual(record.before, 11)
            record.before = 42
            self.assertEqual(record.before, 42)
        except Exception as e:
            self.fail(e)

    def test_after(self):
        try:
            record = Reference(self.conf, self.key, self.before, self.after)
            self.assertEqual(record.after, 143)
            record.after = 511
            self.assertEqual(record.after, 511)
        except Exception as e:
            self.fail(e)

    def test_load(self):
        try:
            record = Reference(self.conf, self.key, self.before, self.after)
            data = record.dump()
            new_record = Reference(self.conf)
            new_record.load(data)
            self.assertEqual(record.key, new_record.key)
            self.assertEqual(record.before, new_record.before)
            self.assertEqual(record.after, new_record.after)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            record = Reference(self.conf, self.key, self.before, self.after)
            data = record.dump()
            new_record = Reference(self.conf, data=data)
            self.assertEqual(record.key, new_record.key)
            self.assertEqual(record.before, new_record.before)
            self.assertEqual(record.after, new_record.after)
        except Exception as e:
            self.fail(e)


class TestOpaqueData(TestCase):
    def setUp(self) -> None:
        self.conf = tree_conf(512, 10, 16, 32)
        self.data = os.urandom(1024)

    def test_load(self):
        try:
            record = OpaqueData(self.conf, self.data)
            data = record.dump()
            new_record = OpaqueData(self.conf)
            new_record.load(data)
            self.assertEqual(record.data, new_record.data)
        except Exception as e:
            self.fail(e)

    def test_dump(self):
        try:
            record = OpaqueData(self.conf, self.data)
            data = record.dump()
            new_record = OpaqueData(self.conf, data=data)
            self.assertEqual(record.data, new_record.data)
        except Exception as e:
            self.fail(e)
