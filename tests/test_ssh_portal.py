"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import asyncio
import argparse
import logging
import unittest

import asyncssh

from angelos.starter import Starter
from angelos.policy.entity import PersonGeneratePolicy, ChurchGeneratePolicy
from support import random_person_entity_data, random_church_entity_data


class TestPortal(unittest.TestCase):
    def setUp(self):
        self.c_ent = PersonGeneratePolicy()
        self.c_ent.generate(**random_person_entity_data(1)[0])
        self.s_ent = ChurchGeneratePolicy()
        self.s_ent.generate(**random_church_entity_data(1)[0])

    def tearDown(self):
        pass

    def test_connection(self):
        """Creating entities and do portal client/server authentication"""
        logging.info('====== %s ======' % 'test_connection')
        server = Starter.portal_server(
            self.s_ent.entity, self.s_ent.privkeys,
            'localhost', 22)
        print(server)
        # await asyncio.sleep(10)
        # Starter.portal_client(
        #    self.c_ent.entity, self.c_ent.privkeys, self.s_ent.keys,
        #    'localhost', 22)
        asyncio.get_event_loop().run_forever()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    asyncssh.logging.set_debug_level(3)
    unittest.main(argv=['first-arg-is-ignored'])
