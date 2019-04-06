import sys
sys.path.append('../angelos')  # noqa

import unittest
import argparse
import tempfile
import logging
import libnacl

from support import random_person_entity_data
from angelos.facade.facade import Facade


class TestConceal(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.home = self.dir.name
        self.secret = libnacl.secret.SecretBox().sk

    def tearDown(self):
        self.dir.cleanup()

    def test_create_open(self):
        """Creating new facade with archives and then open it"""
        logging.info('====== %s ======' % 'test_create_open')
        entity_data = random_person_entity_data(1)[0]

        facade = Facade.setup(self.home, entity_data, self.secret)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    unittest.main(argv=['first-arg-is-ignored'])
