#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
import datetime
from unittest import TestCase
from uuid import uuid4, UUID

from bplustree.serializer import Serializer, IntSerializer, StrSerializer, UUIDSerializer, DatetimeUTCSerializer


class TestSerializer(TestCase):
    def test_serialize(self):
        try:
            with self.assertRaises(TypeError):
                s = Serializer()
        except Exception as e:
            self.fail(e)

    def test_deserialize(self):
        try:
            with self.assertRaises(TypeError):
                s = Serializer()
        except Exception as e:
            self.fail(e)


class TestIntSerializer(TestCase):
    def test_serialize(self):
        try:
            s = IntSerializer()
            data = s.serialize(2**31, 4)
            self.assertIsInstance(data, bytes)
            self.assertEqual(len(data), 4)
        except Exception as e:
            self.fail(e)

    def test_deserialize(self):
        try:
            s = IntSerializer()
            value = s.deserialize(b"\x80\x00\x00\x00")
            self.assertIsInstance(value, int)
            self.assertEqual(value, 2 ** 31)
        except Exception as e:
            self.fail(e)


class TestStrSerializer(TestCase):
    def test_serialize(self):
        try:
            s = StrSerializer()
            with self.assertRaises(ValueError):
                s.serialize("Hello, world!", 10)

            data = s.serialize("Hello, world!", 13)
            self.assertIsInstance(data, bytes)
        except Exception as e:
            self.fail(e)

    def test_deserialize(self):
        try:
            s = StrSerializer()
            value = s.deserialize(b"Hello, world!")
            self.assertIsInstance(value, str)
            self.assertEqual(value, "Hello, world!")
        except Exception as e:
            self.fail(e)


class TestUUIDSerializer(TestCase):
    def test_serialize(self):
        try:
            s = UUIDSerializer()
            u = uuid4()
            data = s.serialize(u, 0)
            self.assertIsInstance(data, bytes)
            self.assertEqual(data, u.bytes)
        except Exception as e:
            self.fail(e)

    def test_deserialize(self):
        try:
            s = UUIDSerializer()
            u = uuid4()
            data = s.deserialize(u.bytes)
            self.assertIsInstance(data, UUID)
            self.assertEqual(data, u)
        except Exception as e:
            self.fail(e)


class TestDatetimeUTCSerializer(TestCase):

    def __test(self):
        s = DatetimeUTCSerializer()
        dt = datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=2)))
        data = s.serialize(dt, 0)
        self.assertIsInstance(data, bytes)
        self.assertEqual(s.deserialize(data), dt)

    def test_serialize(self):
        try:
            self.__test()
        except Exception as e:
            self.fail(e)

    def test_deserialize(self):
        try:
            try:
                self.__test()
            except Exception as e:
                self.fail(e)
        except Exception as e:
            self.fail(e)
