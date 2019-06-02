# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Dummy data generation utilities.
"""

import random

from .support import (
    random_church_entity_data, random_person_entity_data, generate_filename,
    generate_data)
from ..operation.setup import SetupChurchOperation
from ..policy import (
    NetworkPolicy, StatementPolicy, MessagePolicy, EnvelopePolicy)
from ..operation.setup import SetupPersonOperation


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

    async def make_community(self, facade):
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
            mail.add(EnvelopePolicy.wrap(
                person, facade.portfolio, MessagePolicy.mail(
                    person, facade.portfolio).message(
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

        # Connect between facade and church
        StatementPolicy.verified(church, facade.portfolio)
        StatementPolicy.trusted(church, facade.portfolio)
        StatementPolicy.trusted(facade.portfolio, church)

        ownjected = set()
        for person in persons:
            _, _, owner = await facade.import_portfolio(person)
            ownjected |= owner
        _, _, owner = await facade.import_portfolio(church)
        ownjected |= owner
        rejected = await facade.docs_to_portfolios(ownjected)  # noqa f841
        inboxed = await facade.mail.mail_to_inbox(mail)  # noqa f841
