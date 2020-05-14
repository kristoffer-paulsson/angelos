#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Dummy data generation utilities."""
import random
import binascii
import os

from libangelos.const import Const
from libangelos.facade.facade import Facade
from libangelos.storage.helper import Glue
from .generator import (
    random_church_entity_data,
    random_ministry_entity_data,
    random_person_entity_data,
    generate_filename,
    generate_data,
)
from libangelos.operation.setup import SetupChurchOperation
from libangelos.policy.domain import NetworkPolicy
from libangelos.policy.verify import StatementPolicy
from libangelos.policy.message import MessagePolicy, EnvelopePolicy
from libangelos.facade.facade import (
    PersonClientFacade, MinistryClientFacade, ChurchClientFacade,
    PersonServerFacade, MinistryServerFacade, ChurchServerFacade)
from libangelos.operation.setup import SetupPersonOperation

import libnacl


class DummyPolicy:
    """Policy to generate dummy data according to scenarios."""

    @staticmethod
    def __create_generic_facade(
        homedir: str,
        entity_data: dict,
        cls: type,
    ) -> bytes:
        """Generic entity facade generator."""
        secret = libnacl.secret.SecretBox().sk
        facade = Glue.run_async(cls.setup(
            homedir, secret, Const.A_ROLE_PRIMARY, entity_data))
        facade.archive(Const.CNL_VAULT).close()
        with open(os.path.join(homedir, 'secret.key'), 'w') as key:
            key.write(binascii.hexlify(secret).decode())
        return secret

    @staticmethod
    def create_person_facade(
        homedir: str,
        server: bool = False
    ) -> bytes:
        """Generate random person facade.

        Parameters
        ----------
        homedir : str
            The destination of the encrypted archives.
        server : bool
            Generate a server of client, dedaults to client.

        Returns
        -------
        bytes
            NaCl symmetric encryption key used.

        """
        entity_data = random_person_entity_data()[0]
        return DummyPolicy.__create_generic_facade(
            homedir, entity_data,
            PersonServerFacade if server else PersonClientFacade)

    @staticmethod
    def create_ministry_facade(
        homedir: str,
        server: bool = False
    ) -> bytes:
        """Generate random ministry facade.

        Parameters
        ----------
        homedir : str
            The destination of the encrypted archives.
        server : bool
            Generate a server of client, dedaults to client.

        Returns
        -------
        bytes
            NaCl symmetric encryption key used.

        """
        entity_data = random_ministry_entity_data()[0]
        return DummyPolicy.__create_generic_facade(
            homedir, entity_data,
            MinistryServerFacade if server else MinistryClientFacade)

    @staticmethod
    def create_church_facade(
        homedir: str,
        server: bool = True
    ) -> bytes:
        """Generate random church facade.

        Parameters
        ----------
        homedir : str
            The destination of the encrypted archives.
        server : bool
            Generate a server of client, dedaults to server.

        Returns
        -------
        bytes
            NaCl symmetric encryption key used.

        """
        entity_data = random_church_entity_data()[0]
        return DummyPolicy.__create_generic_facade(
            homedir, entity_data,
            ChurchServerFacade if server else ChurchClientFacade)

    @staticmethod
    def make_friends(facade, num):
        """Generate X number of friends and import to vault."""
        pass

    @staticmethod
    def make_churches(facade):
        """Generate 5-10 church communitys and import to vault."""
        churches = random_church_entity_data(random.randrange(5, 10))

        sets = []
        for church_data in churches:
            cur_set = SetupChurchOperation.create_new(
                church_data, "server", True
            )
            net = NetworkPolicy(cur_set[0], cur_set[1], cur_set[2])
            net.generate(cur_set[3], cur_set[4])
            cur_set += net.network
            sets.append(cur_set)

        facade.import_entity()

        return sets

    @staticmethod
    async def make_community(facade: Facade):
        """
        Creates a community with entities that sends a mail to the given
        facade.

        Parameters
        ----------
        facade : Facade
            The facade to be treated.

        Returns
        -------
        None
            Returns nothing.

        """
        person_datas = random_person_entity_data(201)
        persons = []
        for person_data in person_datas:
            persons.append(SetupPersonOperation.create(person_data))

        # Generate a church
        church = SetupChurchOperation.create(
            random_church_entity_data(1)[0], "server", True
        )
        NetworkPolicy.generate(church)

        mail = set()
        for person in persons:
            StatementPolicy.verified(church, person)
            StatementPolicy.trusted(church, person)
            StatementPolicy.trusted(person, church)
            mail.add(
                EnvelopePolicy.wrap(
                    person,
                    facade.portfolio,
                    MessagePolicy.mail(person, facade.portfolio)
                    .message(
                        generate_filename(postfix="."),
                        generate_data().decode(),
                    )
                    .done(),
                )
            )

        for triad in range(67):
            offset = triad * 3
            triple = persons[offset:offset + 3]

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
