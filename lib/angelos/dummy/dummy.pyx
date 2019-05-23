# cython: language_level=3
"""Dummy data generation utilities."""

import random

from .support import random_church_entity_data
from ..operation.setup import SetupChurchOperation
from ..policy.domain import NetworkPolicy


class DummyPolicy:
    """Policy to generate dummy data according to scenarios."""

    def make_friends(self, facade, num):
        """Generate X number of friends and import to vault."""
        pass

    def make_churches(self, facade):
        """Generate 5-10 church communitys and import to vault."""
        churches = random_church_entity_data(random.randrange(5, 10))

        sets = []
        for church_data in churches:
            cur_set = SetupChurchOperation.create_new(
                church_data, 'server', True)
            net = NetworkPolicy(cur_set[0], cur_set[1], cur_set[2])
            net.generate(cur_set[3], cur_set[4])
            cur_set += net.network
            sets.append(cur_set)

        facade.import_entity()

        return sets
