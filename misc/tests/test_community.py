"""
Testcase community generation.

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import sys
sys.path.append('../angelos')  # noqa

import testing
import argparse
import logging
import tempfile

import yaml
import libnacl

from support import (
    random_church_entity_data, random_person_entity_data, generate_filename,
    generate_data)
from angelos.const import Const
from angelos.policy import (
    NetworkPolicy, StatementPolicy, MessagePolicy, EnvelopePolicy)
from angelos.facade.facade import PersonClientFacade
from angelos.archive.helper import Glue
from angelos.operation.setup import SetupPersonOperation, SetupChurchOperation


class TestCommunity(testing.TestCase):
    """Testcase to generate a fake community."""

    @classmethod
    def setUpClass(cls):
        """Set up and prepare."""
        cls.dir = tempfile.TemporaryDirectory()
        cls.home = cls.dir.name
        cls.secret = libnacl.secret.SecretBox().sk
        cls.facade = Glue.run_async(PersonClientFacade.setup(
            cls.home, cls.secret, Const.A_ROLE_PRIMARY,
            random_person_entity_data(1)[0]))

    @classmethod
    def tearDownClass(cls):
        """Tear down and clean up."""
        del cls.facade
        cls.dir.cleanup()

    def test_generate_community(self):
        """Generate one thousand persons."""
        logging.info('====== %s ======' % 'test_03_generate_persons')

        person_datas = random_person_entity_data(3)  # 201
        persons = []
        for person_data in person_datas:
            persons.append(SetupPersonOperation.create(person_data))

        # Generate a church
        church = SetupChurchOperation.create(
            random_church_entity_data(1)[0], 'server', True)
        NetworkPolicy.generate(church)

        mail = set()
        for person in persons:
            StatementPolicy.verified(church, person)
            StatementPolicy.trusted(church, person)
            StatementPolicy.trusted(person, church)
            mail.add(EnvelopePolicy.wrap(person, church, MessagePolicy.mail(
                person, church).message(
                    generate_filename(postfix='.'),
                    generate_data().decode()).done()))

        for triad in range(1):  # 67
            offset = triad*3
            triple = persons[offset:offset+3]

            StatementPolicy.trusted(triple[0], triple[1])
            StatementPolicy.trusted(triple[0], triple[2])

            StatementPolicy.trusted(triple[1], triple[0])
            StatementPolicy.trusted(triple[1], triple[2])

            StatementPolicy.trusted(triple[2], triple[0])
            StatementPolicy.trusted(triple[2], triple[1])

        # Connect between facade and church
        StatementPolicy.verified(church, self.facade.portfolio)
        StatementPolicy.trusted(church, self.facade.portfolio)
        StatementPolicy.trusted(self.facade.portfolio, church)

        # Import persons into vault
        ownjected = set()
        for person in persons:
            _, _, owner = Glue.run_async(self.facade.import_portfolio(person))
            ownjected |= owner
        _, _, owner = Glue.run_async(self.facade.import_portfolio(church))
        ownjected |= owner
        rejected = Glue.run_async(self.facade.docs_to_portfolios(ownjected))

        inboxed = Glue.run_async(self.facade.mail.mail_to_inbox(mail))

        print(rejected)
        print(inboxed)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    testing.main(argv=['first-arg-is-ignored'])
