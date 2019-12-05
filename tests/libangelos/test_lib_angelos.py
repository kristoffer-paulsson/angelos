import unittest

import lib_angelos.test_event as test_event
import lib_angelos.test_notifierMixin as test_notifierMixin
import lib_angelos.test_observerMixin as test_observerMixin


def build_suite():
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    # Testing reactive
    suite.addTest(loader.loadTestsFromModule(test_event))
    suite.addTest(loader.loadTestsFromModule(test_notifierMixin))
    suite.addTest(loader.loadTestsFromModule(test_observerMixin))

    return suite


if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=3)
    result = runner.run(build_suite())