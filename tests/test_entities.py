import sys
sys.path.append('../angelos')  # noqa

import unittest

import support
from angelos.document.entities import Person
from angelos.policy.entity import PersonGeneratePolicy


class TestEntities(unittest.TestCase):
    def setUp(self):
        pass

    def tearDown(self):
        pass

    def test_create_person(self):
        """
        Populating a Person Entity document class with random 'valid' data.
        """
        data = support.random_person_entity_data(1)
        try:
            self.assertIsInstance(Person(nd=data[0]), Person)
        except Exception as e:
            raise e
            # self.fail(e)

    def test_person_generate_policy(self):
        """
        Generating a Person Entity with keys using a GeneratePolicy.
        """
        data = support.random_person_entity_data(1)
        try:
            policy = PersonGeneratePolicy()
            self.assertTrue(policy.generate(**data[0]))
            self.assertTrue(policy.verify(
                policy.entity, policy.entity, policy.keys))
            self.assertTrue(policy.verify(
                 policy.private, policy.entity, policy.keys))
            self.assertTrue(policy.verify(
                policy.keys, policy.entity, policy.keys))
        except Exception as e:
            self.fail(e)


if __name__ == '__main__':
    unittest.main(argv=['first-arg-is-ignored'])
