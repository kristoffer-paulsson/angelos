import sys
sys.path.append('../angelos')  # noqa

import unittest
import copy

import support
from angelos.document.entities import Person
from angelos.policy.entity import PersonGeneratePolicy, PersonUpdatePolicy
from angelos.policy.accept import (
    ImportPolicy, ImportEntityPolicy, ImportUpdatePolicy)


class TestImportPolicies(unittest.TestCase):
    def setUp(self):
        self.data = support.random_person_entity_data(1)
        self.policy = PersonGeneratePolicy()
        self.policy.generate(**self.data[0])

    def tearDown(self):
        pass

    def test_import_person(self):
        """
        Import a person entity with keys
        """
        try:
            self.assertTrue(ImportEntityPolicy().person(
                self.policy.entity, self.policy.keys))
        except Exception as e:
            self.fail(e)

    def test_import_updated_person(self):
        """
        Importing an updated person entity
        """
        upolicy = PersonUpdatePolicy()
        entity = upolicy.change(
            copy.deepcopy(self.policy.entity), family_name='Doe')
        upolicy.update(entity, self.policy.private, self.policy.keys)
        # try:
        imp = ImportUpdatePolicy(
            self.policy.entity, self.policy.keys)
        self.assertTrue(imp.person(upolicy.entity))
        # except Exception as e:
        #    self.fail(e)


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
