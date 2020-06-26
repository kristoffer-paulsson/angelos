import logging
import os
import random
import sys
import tracemalloc
import uuid
import datetime
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.archive7.tree import SimpleBTree, TreeAnalyzer, MultiBTree

from libangelos.utils import Util

from archive7.tree import RecordBundle, TreeRescue


class TestTreeAnalyzer(TestCase):
    LOG_LEVEL = logging.DEBUG

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.LOG_LEVEL)

        cls.database = os.path.join(os.path.dirname(__file__), "database.db")
        # cls.database = os.path.join(cls.home, "database.db")

        if not os.path.isfile(cls.database):
            raise OSError("Test file doesn't exists")

        cls.bank = dict()

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""
        cls.bank = None

    def test__load_meta(self):
        self.fail()

    def test_print_stats(self):
        try:
            analyzer = TreeAnalyzer(open(self.database, "rb"), SimpleBTree)
            analyzer.print_stats()
            analyzer.pager.close()
        except Exception as e:
            self.fail(e)

    def test_iterator(self):
        self.fail()

    def test_iterate_records(self):
        self.fail()

    def test_kind_from_data(self):
        self.fail()

    def test_page_to_node(self):
        self.fail()

    def test_records(self):
        self.fail()

    def test_references(self):
        self.fail()

    def test_load_pairs(self):
        try:
            pass
        except Exception as e:
            self.fail(e)


class TestTreeRescue(TestCase):
    LOG_LEVEL = logging.DEBUG

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.LOG_LEVEL)

        cls.home = os.path.dirname(__file__)
        cls.database = os.path.join(cls.home, "database_old.db")
        cls.rescue = os.path.join(cls.home, "database.db")

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""
        pass

    def test_rescue(self):
        try:
            rescue = TreeRescue(open(self.database, "rb+"), SimpleBTree)
            rescue.rescue(open(self.rescue, "wb+"))
            rescue.analyzer.pager.close()
        except Exception as e:
            self.fail(e)


class TestTreeBase(TestCase):
    ORDER = 32
    VALUE_SIZE = 64
    ITERATIONS = 1000
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

    def test_1_insert(self):
        """Insert ITERATIONS number of key/value-pairs and then analyze them with analyzer."""
        try:
            self._tree()
            bank = dict()
            logging.info("Start inserting %s key/value-pairs" % self.ITERATIONS)
            for iteration in range(self.ITERATIONS):

                pair = self.key_pair()
                self.tree.insert(pair[0], pair[1])
                bank[pair[0]] = pair[1]
                self.loop(iteration)

            self.tree.close()
            self.sumitup(iteration)
            logging.info("Done inserting key/value-pairs")

            logging.info("Start analyzing %s key/value-pairs" % self.ITERATIONS)
            self._analyzer()
            iteration = 0
            keys = list()
            bank_keys = list(bank.keys())

            for rec in self.analyzer.records():
                keys.append(rec.key)
                self.assertIn(rec.key, bank_keys)
                self.assertEqual(rec.value, bank[rec.key])
                self.loop(iteration)
                iteration += 1

            bank_keys.sort()
            keys.sort()
            self.assertEqual(bank_keys, keys)

            self.analyzer.print_stats()
            self.analyzer.pager.close()
            self.sumitup(iteration)
            logging.info("Done analyzing key/value-pairs")

        except Exception as e:
            logging.warning("Failed unittest at iteration %s" % iteration)
            self.fail(e)

    def test_2_get(self):
        """Get all key/value-pairs from the database and compare to the bank."""
        try:
            self._analyzer()
            bundle = self.analyzer.load_pairs()
            self.analyzer.pager.close()
            self._tree()
            logging.info("Start getting %s key/value-pairs" % len(bundle.keys))

            iteration = 0
            for key in bundle.keys:
                value = self.tree.get(key)
                self.assertIsNot(value, None)
                self.assertEqual(value, bundle.pairs[key])
                self.loop(iteration)
                iteration += 1

            self.sumitup(iteration)
            logging.info("Done getting key/value-pairs")
        except Exception as e:
            logging.warning("Failed unittest at iteration %s" % iteration)
            print(key)
            self.fail(e)

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