import sys
sys.path.append('../angelos')  # noqa

import unittest
import argparse
import tempfile
import logging
import libnacl

from support import random_person_entity_data
from angelos.facade.facade import PersonClientFacade
from angelos.document.entities import Person, Keys
from angelos.document.domain import Domain, Node
from angelos.policy.entity import PersonGeneratePolicy


class TestFacade(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.dir = tempfile.TemporaryDirectory()
        cls.home = cls.dir.name
        cls.secret = libnacl.secret.SecretBox().sk
        cls.facade = PersonClientFacade.setup(
            cls.home, cls.secret, random_person_entity_data(1)[0])
        cls.ext_policy = PersonGeneratePolicy()
        cls.ext_policy.generate(**random_person_entity_data(1)[0])

    @classmethod
    def tearDownClass(cls):
        del cls.facade
        cls.dir.cleanup()

    def test_01_create(self):
        """Creating new facade with archives and then open it"""
        logging.info('====== %s ======' % 'test_01_create')

        try:
            self.assertIsInstance(self.facade.entity, Person)
            self.assertIsInstance(self.facade.keys, Keys)
            self.assertIsInstance(self.facade.domain, Domain)
            self.assertIsInstance(self.facade.node, Node)
        except Exception as e:
            self.fail(e)

    def test_02_import(self):
        """Creating new facade with archives and then open it"""
        logging.info('====== %s ======' % 'test_02_import')

        # try:
        self.facade.import_entity(
            self.ext_policy.entity, self.ext_policy.keys)
        self.assertRaises(
            Exception, self.facade.import_entity,
            self.ext_policy.entity, self.ext_policy.keys)
        # except Exception as e:
        #    self.fail(e)

    def test_03_load_key_entity(self):
        """Creating new facade with archives and then open it"""
        logging.info('====== %s ======' % 'test_03_load_key_entity')

        try:
            self.assertEqual(self.facade.find_entity(
                self.ext_policy.entity.issuer).export(),
                self.ext_policy.entity.export())
            self.assertEqual(self.facade.find_keys(
                self.ext_policy.entity.issuer)[0].export(),
                self.ext_policy.keys.export())
        except Exception as e:
            self.fail(e)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    unittest.main(argv=['first-arg-is-ignored'])
