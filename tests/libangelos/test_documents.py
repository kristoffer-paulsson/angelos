import unittest

import documents.test_issueMixin as test_issueMixin
import documents.test_ownerMixin as test_ownerMixin
import documents.test_updatedMixin as test_updatedMixin


def build_suite():
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    # Testing of fields
    suite.addTest(loader.loadTestsFromModule(test_issueMixin))
    suite.addTest(loader.loadTestsFromModule(test_ownerMixin))
    suite.addTest(loader.loadTestsFromModule(test_updatedMixin))

    return suite


if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=3)
    result = runner.run(build_suite())