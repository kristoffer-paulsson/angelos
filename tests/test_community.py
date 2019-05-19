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
    random_person_entity_data)
from angelos.operation.setup import (
    SetupChurchOperation, SetupMinistryOperation, SetupPersonOperation)
from angelos.policy.domain import NetworkPolicy
from angelos.policy.verify import StatementPolicy


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

        # (entity, privkeys, keys, domain, node)
        # Generate persons to the community
        person_datas = random_person_entity_data(201)
        persons = []
        for person_data in person_datas:
            persons.append(SetupPersonOperation.create_new(person_data))

        # Generate a church
        church_data = random_church_entity_data(1)[0]
        entity, privkeys, keys, domain, node = SetupChurchOperation.create_new(
            church_data, 'server', True)
        net = NetworkPolicy(entity, privkeys, keys)
        net.generate(domain, node)
        church = (entity, privkeys, keys, domain, node, net.network)

        verifieds = []
        trusts = []
        stat_policy = StatementPolicy(entity, privkeys, keys)

        for person in persons:
            stat_policy.verified(person[0])
            verifieds.append(stat_policy.statement)
            stat_policy.trusted(person[0])
            trusts.append(stat_policy.statement)

            stat_p2 = StatementPolicy(person[0], person[1], person[2])
            stat_p2.trusted(entity)
            trusts.append(stat_p2.statement)

        for triad in range(67):
            offset = triad*3
            triple = persons[offset:offset+3]

            stat_p1 = StatementPolicy(triple[0][0], triple[0][1], triple[0][2])
            stat_p1.trusted(triple[1][0])
            verifieds.append(stat_p1.statement)
            stat_p1.trusted(triple[2][0])
            verifieds.append(stat_p1.statement)

            stat_p2 = StatementPolicy(triple[1][0], triple[1][1], triple[1][2])
            stat_p2.trusted(triple[0][0])
            verifieds.append(stat_p2.statement)
            stat_p2.trusted(triple[2][0])
            verifieds.append(stat_p2.statement)

            stat_p3 = StatementPolicy(triple[2][0], triple[2][1], triple[2][2])
            stat_p3.trusted(triple[0][0])
            verifieds.append(stat_p3.statement)
            stat_p3.trusted(triple[1][0])
            verifieds.append(stat_p3.statement)

        kw = {
            'explicit_start': True,
            'explicit_end': True
        }
        print(yaml.dump(church[0].export_yaml(), **kw))
        print(yaml.dump(church[1].export_yaml(), **kw))
        print(yaml.dump(church[2].export_yaml(), **kw))
        print(yaml.dump(church[3].export_yaml(), **kw))
        print(yaml.dump(church[4].export_yaml(), **kw))

        for pd in persons:
            print(yaml.dump(pd[0].export_yaml(), **kw))
            print(yaml.dump(pd[1].export_yaml(), **kw))
            print(yaml.dump(pd[2].export_yaml(), **kw))
            print(yaml.dump(pd[3].export_yaml(), **kw))
            print(yaml.dump(pd[4].export_yaml(), **kw))

        for vd in verifieds:
            print(yaml.dump(vd.export_yaml(), **kw))
        for td in trusts:
            print(yaml.dump(td.export_yaml(), **kw))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Unittesting')
    parser.add_argument(
        '--debug', help='Debugging', action='store_true', default=False)

    args = parser.parse_args()
    if args.debug:
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)

    unittest.main(argv=['first-arg-is-ignored'])
