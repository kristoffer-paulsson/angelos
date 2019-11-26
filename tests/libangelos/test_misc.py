import unittest

import documents.test_storedLetter as test_storedLetter


def build_suite():
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    # Testing of fields
    suite.addTest(loader.loadTestsFromModule(test_storedLetter))

    return suite


if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=3)
    result = runner.run(build_suite())