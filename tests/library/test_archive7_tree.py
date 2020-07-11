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
import logging
import os
import random
import sys
import tracemalloc
import uuid
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.archive7.tree import SimpleBTree, TreeAnalyzer, MultiBTree


class TestTreeBase(TestCase):
    ORDER = 32
    VALUE_SIZE = 64
    ITERATIONS = 128
    KLASS = None

    LOOP = 5000

    LOG_LEVEL = logging.DEBUG

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.LOG_LEVEL)

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""
        pass

    def make_data(self):
        return None

    def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""
        random.seed(0)
        self.dir = TemporaryDirectory()
        self.home = os.path.dirname(self.dir.name)
        self.database = os.path.join(self.home, "database.db")
        self.data = self.make_data()

        if os.path.isfile(self.database):
            os.unlink(self.database)

    def tearDown(self) -> None:
        """Tear down after the test."""
        if hasattr(self, "tree"):
            self.tree.close()
        if hasattr(self, "analyzer"):
            self.analyzer.pager.close()
        self.data = dict()
        self.dir.cleanup()

    def _tree(self):
        self.tree = self.KLASS.factory(
            open(self.database, "rb+" if os.path.isfile(self.database) else "wb+"),
            self.ORDER,
            self.VALUE_SIZE
        )

    def _analyzer(self):
        self.analyzer = TreeAnalyzer(
            open(self.database, "rb+" if os.path.isfile(self.database) else "wb+"),
            SimpleBTree
        )

    def loop(self, iteration):
        """Print iteration in loop."""
        if not iteration % self.LOOP and iteration is not 0:
            logging.debug("%s %s" % (datetime.datetime.now(), iteration))

    def sumitup(self, iteration):
        logging.info("%s %s" % (datetime.datetime.now(), iteration))
        logging.info("Filesize: %s" % os.stat(self.database).st_size)

    def key_pair(self) -> tuple:
        """Generate random key/value-pair."""
        return uuid.UUID(bytes=os.urandom(16)), os.urandom(self.VALUE_SIZE)


class TestSimpleBTree(TestTreeBase):
    KLASS = SimpleBTree

    def make_data(self):
        return {uuid.uuid4(): os.urandom(self.VALUE_SIZE) for _ in range(self.ITERATIONS)}

    def test_insert(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            random.shuffle(keys)
            for key in keys:
                self.assertIsNotNone(self.tree.get(key))
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)

    def test_update(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            for key in keys[:self.ITERATIONS // 2]:
                data = os.urandom(self.VALUE_SIZE)
                self.data[key] = data
                self.tree.update(key, data)

            random.shuffle(keys)
            for key in keys:
                self.assertIsNotNone(self.tree.get(key))
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)

    def test_get(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            random.shuffle(keys)
            for key in keys:
                self.assertIsNotNone(self.tree.get(key))
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)

    def test_delete(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            for key in keys[:self.ITERATIONS // 2]:
                self.tree.delete(key)

            for key in keys[:self.ITERATIONS // 2]:
                self.assertIsNone(self.tree.get(key))

            for key in keys[self.ITERATIONS // 2:]:
                self.assertIsNotNone(self.tree.get(key))
                self.assertEqual(self.tree.get(key), self.data[key])
        except Exception as e:
            self.fail(e)


class TestMultiBTree(TestTreeBase):
    KLASS = MultiBTree

    def make_data(self):
        data = dict()
        keys = [uuid.UUID(int=i) for i in range(self.ITERATIONS)]
        shuffled = keys
        random.shuffle(shuffled)

        for key in keys:
            data[key] = list()
            for item in range(random.randrange(1, 999)):
                data[key].append(os.urandom(self.VALUE_SIZE))

        return data

    def test_insert(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            random.shuffle(keys)
            for key in keys:
                values = self.tree.get(key)
                self.assertNotEqual(values, list())
                self.assertEqual(set(values), set(self.data[key]))
        except Exception as e:
            self.fail(e)

    def test_update(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            random.shuffle(keys)
            for key in keys[len(keys) // 2:]:
                insertions = list(os.urandom(self.VALUE_SIZE) for _ in range(random.randrange(1, 99)))
                random.shuffle(self.data[key])
                deletions = set(self.data[key][:random.randrange(0, len(self.data[key]))])
                self.tree.update(key, insertions, deletions)

                self.data[key] += insertions
                new = list()
                for item in self.data[key]:
                    if item not in deletions:
                        new.append(item)
                self.data[key] = new

            cnt = 0
            for key in keys:
                cnt += 1
                values = self.tree.get(key)
                self.assertNotEqual(values, list())
                self.assertEqual(set(values), set(self.data[key]))

        except Exception as e:
            self.fail(e)

    def test_get(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            random.shuffle(keys)
            for key in keys:
                values = self.tree.get(key)
                self.assertNotEqual(values, list())
                self.assertEqual(set(values), set(self.data[key]))
        except Exception as e:
            self.fail(e)

    def test_delete(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)
            for key in keys:
                self.tree.insert(key, self.data[key])

            for key in keys[len(keys) // 2:]:
                self.tree.delete(key)

            for key in keys[len(keys) // 2:]:
                self.assertEqual(self.tree.get(key), list())

            for key in keys[:len(keys) // 2]:
                values = self.tree.get(key)
                self.assertNotEqual(values, list())
                self.assertEqual(set(values), set(self.data[key]))
        except Exception as e:
            self.fail(e)

    def test_traverse(self):
        try:
            self._tree()
            keys = list(self.data.keys())
            random.shuffle(keys)

            for key in keys:
                self.tree.insert(key, self.data[key])

            random.shuffle(keys)
            for key in keys:
                values = set(self.data[key])
                for item in self.tree.traverse(key):
                    self.assertIn(item, values)
        except Exception as e:
            self.fail(e)