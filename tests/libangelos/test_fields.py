import unittest

import documents.test_field as test_field
import documents.test_binaryField as test_binaryField
import documents.test_choiceField as test_choiceField
import documents.test_dateField as test_dateField
import documents.test_dateTimeField as test_dateTimeField
import documents.test_documentField as test_documentField
import documents.test_emailField as test_emailField
import documents.test_IPField as test_IPField
import documents.test_regexField as test_regexField
import documents.test_signatureField as test_signatureField
import documents.test_stringField as test_stringField
import documents.test_typeField as test_typeField
import documents.test_uuidField as test_uuidField


def build_suite():
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    suite.addTest(loader.loadTestsFromModule(test_field))
    suite.addTest(loader.loadTestsFromModule(test_typeField))
    suite.addTest(loader.loadTestsFromModule(test_uuidField))
    suite.addTest(loader.loadTestsFromModule(test_IPField))
    suite.addTest(loader.loadTestsFromModule(test_dateField))
    suite.addTest(loader.loadTestsFromModule(test_dateTimeField))
    suite.addTest(loader.loadTestsFromModule(test_binaryField))
    suite.addTest(loader.loadTestsFromModule(test_signatureField))
    suite.addTest(loader.loadTestsFromModule(test_stringField))
    suite.addTest(loader.loadTestsFromModule(test_regexField))
    suite.addTest(loader.loadTestsFromModule(test_emailField))
    suite.addTest(loader.loadTestsFromModule(test_choiceField))
    suite.addTest(loader.loadTestsFromModule(test_documentField))

    return suite


if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=3)
    result = runner.run(build_suite())