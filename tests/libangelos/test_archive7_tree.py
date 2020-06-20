import logging
import os
import sys
import tracemalloc
import uuid
import datetime
from tempfile import TemporaryDirectory
from unittest import TestCase

from libangelos.archive7.tree import SimpleBTree

from archive7.tree import TreeAnalyzer


class TestSimpleBTree(TestCase):
    ORDER = 128
    KEY_SIZE = 16
    VALUE_SIZE = 64
    ITERATIONS = 10000

    LOOP = 5000

    LOG_LEVEL = logging.DEBUG

    @classmethod
    def setUpClass(cls) -> None:
        """Setup test class with a facade and ten contacts."""
        tracemalloc.start()
        logging.basicConfig(stream=sys.stderr, level=cls.LOG_LEVEL)

        cls.dir = TemporaryDirectory()
        cls.home = cls.dir.name
        cls.database = os.path.join(cls.home, "database.db")

        if os.path.isfile(cls.database):
            raise OSError("File already exists")

        cls.bank = dict()

    @classmethod
    def tearDownClass(cls) -> None:
        """Clean up after test suite."""
        cls.dir.cleanup()
        cls.bank = None

    def setUp(self) -> None:
        """Set up a case with a fresh copy of portfolios and facade"""

        self.tree = SimpleBTree.factory(
            open(self.database, "rb+" if os.path.isfile(self.database) else "wb+"),
            self.ORDER,
            self.VALUE_SIZE
        )

    def tearDown(self) -> None:
        """Tear down after the test."""
        self.tree.close()

    def loop(self, iteration):
        if not iteration % self.LOOP and iteration is not 0:
            logging.debug("%s %s" % (datetime.datetime.now(), iteration))

    def sumitup(self, iteration):
        logging.info("%s %s" % (datetime.datetime.now(), iteration))
        logging.info("Filesize: %s" % os.stat(os.path.join(self.home, "database.db")).st_size)

    def key_pair(self) -> tuple:
        """Generate random key/value-pair."""
        return uuid.UUID(bytes=os.urandom(self.KEY_SIZE)), os.urandom(self.VALUE_SIZE)

    def test_1_insert(self):
        """Insert ITERATIONS number of key/value-pairs and then analyze them with analyzer."""
        try:
            logging.info("Start inserting %s key/value-pairs" % self.ITERATIONS)
            for iteration in range(self.ITERATIONS):

                pair = self.key_pair()
                self.tree.insert(pair[0], pair[1])
                self.bank[pair[0]] = pair[1]
                self.loop(iteration)

            self.sumitup(iteration)
            self.tree.close()
            logging.info("Done inserting key/value-pairs" )

            logging.info("Start analyzing %s key/value-pairs" % self.ITERATIONS)
            analyzer = TreeAnalyzer(open(self.database, "rb"), SimpleBTree)
            iteration = 0
            keys = list()

            for rec in analyzer.records():
                keys.append(rec.key)
                self.assertEqual(rec.value, self.bank[rec.key])
                self.loop(iteration)
                iteration += 1

            bank_keys = list(self.bank.keys())
            bank_keys.sort()
            keys.sort()
            self.assertEqual(bank_keys, keys)

            analyzer.pager.close()
            self.sumitup(iteration)
            logging.info("Done analyzing key/value-pairs")

        except Exception as e:
            logging.warning("Failed unittest at iteration %s" % iteration)
            self.fail(e)

    def test_2_get(self):
        """Get all key/value-pairs from the database and compare to the bank."""
        try:
            logging.info("Start getting %s key/value-pairs" % self.ITERATIONS)
            iteration = 0
            for key in list(self.bank.keys()):
                value = self.tree.get(key)
                self.assertIsNot(value, None)
                self.assertEqual(value, self.bank[key])
                self.loop(iteration)
                iteration += 1

            self.sumitup(iteration)
            logging.info("Done getting key/value-pairs")
        except Exception as e:
            logging.warning("Failed unittest at iteration %s" % iteration)
            self.fail(e)