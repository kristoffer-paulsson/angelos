"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import unittest
import copy
import logging

import support
from angelos.document.entities import Keys, PrivateKeys
from angelos.document.statements import Trusted
from angelos.policy.crypto import Crypto
from angelos.policy.entity import PersonGeneratePolicy, PersonUpdatePolicy
from angelos.policy.accept import (
    ImportPolicy, ImportEntityPolicy, ImportUpdatePolicy)


class TestImportPolicies(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    def setUp(self):
        self.data = support.random_person_entity_data(1)
        self.policy = PersonGeneratePolicy()
        self.policy.generate(**self.data[0])

    def test_01_import_person(self):
        """
        Import a person entity with keys
        """
        logging.info('====== %s ======' % 'test_01_import_person')

        try:
            self.assertTrue(ImportEntityPolicy().person(
                self.policy.entity, self.policy.keys))
        except Exception as e:
            self.fail(e)

    def test_02_import_updated_person(self):
        """
        Importing an updated person entity
        """
        logging.info('====== %s ======' % 'test_02_import_updated_person')

        upolicy = PersonUpdatePolicy()
        entity = upolicy.change(
            copy.deepcopy(self.policy.entity), family_name='Doe')
        upolicy.update(entity, self.policy.privkeys, self.policy.keys)
        try:
            imp = ImportUpdatePolicy(
                self.policy.entity, self.policy.keys)
            self.assertTrue(imp.person(upolicy.entity))
        except Exception as e:
            self.fail(e)

    def test_03_import_newkeys(self):
        """
        Generating new keys for entity and import
        """
        logging.info('====== %s ======' % 'test_03_import_newkeys')

        upolicy = PersonUpdatePolicy()
        self.assertTrue(upolicy.newkeys(
            self.policy.entity, self.policy.privkeys, self.policy.keys))
        self.assertIsInstance(upolicy.keys, Keys)
        self.assertIsInstance(upolicy.privkeys, PrivateKeys)
        try:
            imp = ImportUpdatePolicy(
                self.policy.entity, self.policy.keys)
            self.assertTrue(imp.keys(upolicy.keys))
        except Exception as e:
            self.fail(e)

    def bla_test_04_import_documents(self):
        """
        Importing an arbitrary document
        """
        logging.info('====== %s ======' % 'test_04_import_documents')

        impdoc = ImportPolicy(self.policy.entity, self.policy.keys)
        try:
            trusted = Trusted(nd={'owner': self.policy.entity.id,
                                  'issuer': self.policy.entity.id})
            Crypto.sign(
                trusted, self.policy.entity,
                self.policy.privkeys, self.policy.keys)
            self.assertTrue(impdoc.document(trusted))
            # self.assertTrue(impdoc.envelope())
        except Exception as e:
            self.fail(e)


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
