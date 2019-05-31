import sys
sys.path.append('../angelos')  # noqa

import unittest
import argparse
import logging
import os
import pickle

import yaml

from support import (
    random_church_entity_data, random_ministry_entity_data,
    random_person_entity_data, generate_filename, generate_data)
from angelos.operation.setup import (
    SetupChurchOperation, SetupMinistryOperation, SetupPersonOperation)
from angelos.policy import (
    NetworkPolicy, StatementPolicy, MessagePolicy, EnvelopePolicy)


class TestCommunity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # cls.dir = os.path.join(os.path.dirname(__file__), 'communities')
        # cls.churches = os.path.join(cls.dir, 'churches')
        # os.mkdir(cls.churches)
        # cls.ministries = os.path.join(cls.dir, 'ministries')
        # os.mkdir(cls.ministries)
        # cls.persons = os.path.join(cls.dir, 'persons')
        # os.mkdir(cls.persons)
        pass

    def blatest_01_generate_churches(self):
        """Generate five churches."""
        logging.info('====== %s ======' % 'test_01_generate_churches')

        churches = random_church_entity_data(5)

        for church_data in churches:
            (entity, privkeys, keys, domain, node
             ) = SetupChurchOperation.create_new(church_data, 'server', True)
            net = NetworkPolicy(entity, privkeys, keys)
            net.generate(domain, node)

            cpath = os.path.join(self.churches, str(entity.id))
            os.mkdir(cpath)

            with open(os.path.join(cpath, 'entity.pickle'), 'wb') as f:
                f.write(pickle.dumps(entity))
            with open(os.path.join(cpath, 'keys.pickle'), 'wb') as f:
                f.write(pickle.dumps(keys))
            with open(os.path.join(cpath, 'privkeys.pickle'), 'wb') as f:
                f.write(pickle.dumps(privkeys))
            with open(os.path.join(cpath, 'domain.pickle'), 'wb') as f:
                f.write(pickle.dumps(domain))
            with open(os.path.join(cpath, 'node.pickle'), 'wb') as f:
                f.write(pickle.dumps(node))
            with open(os.path.join(cpath, 'network.pickle'), 'wb') as f:
                f.write(pickle.dumps(net.network))

    def blatest_02_generate_ministries(self):
        """Generate ten ministries."""
        logging.info('====== %s ======' % 'test_02_generate_ministries')

        minitries = random_ministry_entity_data(10)

        for ministry_data in minitries:
            (entity, privkeys, keys, domain, node
             ) = SetupMinistryOperation.create_new(
                 ministry_data, 'server', True)
            net = NetworkPolicy(entity, privkeys, keys)
            net.generate(domain, node)

            mpath = os.path.join(self.ministries, str(entity.id))
            os.mkdir(mpath)

            with open(os.path.join(mpath, 'entity.pickle'), 'wb') as f:
                f.write(pickle.dumps(entity))
            with open(os.path.join(mpath, 'keys.pickle'), 'wb') as f:
                f.write(pickle.dumps(keys))
            with open(os.path.join(mpath, 'privkeys.pickle'), 'wb') as f:
                f.write(pickle.dumps(privkeys))
            with open(os.path.join(mpath, 'domain.pickle'), 'wb') as f:
                f.write(pickle.dumps(domain))
            with open(os.path.join(mpath, 'node.pickle'), 'wb') as f:
                f.write(pickle.dumps(node))
            with open(os.path.join(mpath, 'network.pickle'), 'wb') as f:
                f.write(pickle.dumps(net.network))

    def blatest_03_generate_persons(self):
        """Generate one thousand persons."""
        logging.info('====== %s ======' % 'test_03_generate_persons')

        persons = random_person_entity_data(1000)

        for person_data in persons:
            (entity, privkeys, keys, domain, node
             ) = SetupPersonOperation.create_new(person_data)

            ppath = os.path.join(self.persons, str(entity.id))
            os.mkdir(ppath)

            with open(os.path.join(ppath, 'entity.pickle'), 'wb') as f:
                f.write(pickle.dumps(entity))
            with open(os.path.join(ppath, 'keys.pickle'), 'wb') as f:
                f.write(pickle.dumps(keys))
            with open(os.path.join(ppath, 'privkeys.pickle'), 'wb') as f:
                f.write(pickle.dumps(privkeys))
            with open(os.path.join(ppath, 'domain.pickle'), 'wb') as f:
                f.write(pickle.dumps(domain))
            with open(os.path.join(ppath, 'node.pickle'), 'wb') as f:
                f.write(pickle.dumps(node))

    def test_04_generate_community(self):
        """Generate one thousand persons."""
        logging.info('====== %s ======' % 'test_03_generate_persons')

        person_datas = random_person_entity_data(201)
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

        for triad in range(67):
            offset = triad*3
            triple = persons[offset:offset+3]

            StatementPolicy.trusted(triple[0], triple[1])
            StatementPolicy.trusted(triple[0], triple[2])

            StatementPolicy.trusted(triple[1], triple[0])
            StatementPolicy.trusted(triple[1], triple[2])

            StatementPolicy.trusted(triple[2], triple[0])
            StatementPolicy.trusted(triple[2], triple[1])

        pool = set()

        owner, issuer = church.to_sets()
        pool |= owner | issuer | mail

        for person in persons:
            owner, issuer = person.to_sets()
            pool |= owner | issuer

        for doc in pool:
            print(yaml.dump(
                doc.export_yaml(), explicit_start=True, explicit_end=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    unittest.main(argv=['first-arg-is-ignored'])
