"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from unittest import TestLoader, TextTestRunner, TestSuite

from test_model import TestModel
from test_conceal import TestConceal
from test_archive import TestArchive
from test_replication import TestReplication
from test_entities import TestEntities
from test_vault import TestVault
from test_facade import TestFacade

if __name__ == "__main__":

    loader = TestLoader()
    tests = [
        loader.loadTestsFromTestCase(test)
        for test in (
            TestModel, TestConceal, TestArchive, TestReplication, TestEntities,
            TestVault, TestFacade)
    ]
    suite = TestSuite(tests)

    runner = TextTestRunner(verbosity=0)
    runner.run(suite)
