"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import unittest
import argparse
import tempfile
import logging
import os

from support import random_person_entity_data
from angelos.const import Const
from angelos.policy.entity import PersonGeneratePolicy
from angelos.policy.domain import DomainPolicy, NodePolicy
from angelos.archive.vault import Vault

import libnacl


class TestVault(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.home = self.dir.name
        self.secret = libnacl.secret.SecretBox().sk

    def tearDown(self):
        self.dir.cleanup()

    def test_create_open(self):
        """Creating new vault archive and then open it"""
        logging.info('====== %s ======' % 'test_create_open')
        entity_data = random_person_entity_data(1)[0]

        ent_gen = PersonGeneratePolicy()
        ent_gen.generate(**entity_data)

        dom_gen = DomainPolicy(ent_gen.entity, ent_gen.privkeys, ent_gen.keys)
        dom_gen.generate()

        nod_gen = NodePolicy(ent_gen.entity, ent_gen.privkeys, ent_gen.keys)
        nod_gen.current(dom_gen.domain)

        vault = Vault.setup(
            os.path.join(self.home, Const.CNL_VAULT), ent_gen.entity,
            ent_gen.privkeys, ent_gen.keys, dom_gen.domain, nod_gen.node,
            secret=self.secret)

        vault.close()

        # vault = Vault(os.path.join(self.home, Const.CNL_VAULT), self.secret)
        # vault.close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    unittest.main(argv=['first-arg-is-ignored'])
