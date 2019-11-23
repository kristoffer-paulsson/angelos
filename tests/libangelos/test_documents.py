import unittest

import documents.test_issueMixin as test_issueMixin
import documents.test_ownerMixin as test_ownerMixin
import documents.test_updatedMixin as test_updatedMixin
import documents.test_docType as test_docType
import documents.test_document as test_document
import documents.test_privateKeys as test_privateKeys
import documents.test_keys as test_keys
import documents.test_entity as test_entity
import documents.test_person as test_person
import documents.test_ministry as test_ministry
import documents.test_church as test_church
import documents.test_personMixin as test_personMixin
import documents.test_ministryMixin as test_ministryMixin
import documents.test_churchMixin as test_churchMixin
import documents.test_host as test_host
import documents.test_location as test_location
import documents.test_domain as test_domain
import documents.test_node as test_node


def build_suite():
    suite = unittest.TestSuite()
    loader = unittest.TestLoader()

    # Testing of fields
    suite.addTest(loader.loadTestsFromModule(test_issueMixin))
    suite.addTest(loader.loadTestsFromModule(test_ownerMixin))
    suite.addTest(loader.loadTestsFromModule(test_updatedMixin))
    suite.addTest(loader.loadTestsFromModule(test_docType))
    suite.addTest(loader.loadTestsFromModule(test_document))
    suite.addTest(loader.loadTestsFromModule(test_privateKeys))
    suite.addTest(loader.loadTestsFromModule(test_keys))
    suite.addTest(loader.loadTestsFromModule(test_entity))
    suite.addTest(loader.loadTestsFromModule(test_person))
    suite.addTest(loader.loadTestsFromModule(test_ministry))
    suite.addTest(loader.loadTestsFromModule(test_church))
    suite.addTest(loader.loadTestsFromModule(test_personMixin))
    suite.addTest(loader.loadTestsFromModule(test_ministryMixin))
    suite.addTest(loader.loadTestsFromModule(test_churchMixin))
    suite.addTest(loader.loadTestsFromModule(test_host))
    suite.addTest(loader.loadTestsFromModule(test_location))
    suite.addTest(loader.loadTestsFromModule(test_domain))
    suite.addTest(loader.loadTestsFromModule(test_node))

    return suite


if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=3)
    result = runner.run(build_suite())