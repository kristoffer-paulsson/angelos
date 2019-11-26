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
import documents.test_network as test_network
import documents.test_statement as test_statement
import documents.test_verified as test_verified
import documents.test_trusted as test_trusted
import documents.test_revoked as test_revoked
import documents.test_address as test_address
import documents.test_social as test_social
import documents.test_profile as test_profile
import documents.test_personProfile as test_personProfile
import documents.test_ministryProfile as test_ministryProfile
import documents.test_churchProfile as test_churchProfile
import documents.test_attachment as test_attachment
import documents.test_message as test_message
import documents.test_note as test_note
import documents.test_instant as test_instant
import documents.test_mail as test_mail
import documents.test_share as test_share
import documents.test_report as test_report
import documents.test_header as test_header
import documents.test_envelope as test_envelope


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
    suite.addTest(loader.loadTestsFromModule(test_network))
    suite.addTest(loader.loadTestsFromModule(test_statement))
    suite.addTest(loader.loadTestsFromModule(test_verified))
    suite.addTest(loader.loadTestsFromModule(test_trusted))
    suite.addTest(loader.loadTestsFromModule(test_revoked))
    suite.addTest(loader.loadTestsFromModule(test_address))
    suite.addTest(loader.loadTestsFromModule(test_social))
    suite.addTest(loader.loadTestsFromModule(test_profile))
    suite.addTest(loader.loadTestsFromModule(test_personProfile))
    suite.addTest(loader.loadTestsFromModule(test_ministryProfile))
    suite.addTest(loader.loadTestsFromModule(test_churchProfile))
    suite.addTest(loader.loadTestsFromModule(test_attachment))
    suite.addTest(loader.loadTestsFromModule(test_message))
    suite.addTest(loader.loadTestsFromModule(test_note))
    suite.addTest(loader.loadTestsFromModule(test_instant))
    suite.addTest(loader.loadTestsFromModule(test_mail))
    suite.addTest(loader.loadTestsFromModule(test_share))
    suite.addTest(loader.loadTestsFromModule(test_report))
    suite.addTest(loader.loadTestsFromModule(test_header))
    suite.addTest(loader.loadTestsFromModule(test_envelope))

    return suite


if __name__ == "__main__":
    runner = unittest.TextTestRunner(verbosity=3)
    result = runner.run(build_suite())