# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Dummy data generation utilities."""
import random
import binascii
import os

from ..const import Const
from ..facade.facade import Facade
from ..archive.helper import Glue
from .support import (
    random_church_entity_data,
    random_ministry_entity_data,
    random_person_entity_data,
    generate_filename,
    generate_data,
)
from ..operation.setup import SetupChurchOperation
from ..policy.domain import NetworkPolicy, StatementPolicy
from ..policy.message import MessagePolicy, EnvelopePolicy
from ..facade.facade import (
    PersonClientFacade, MinistryClientFacade, ChurchClientFacade,
    PersonServerFacade, MinistryServerFacade, ChurchServerFacade)
from ..operation.setup import SetupPersonOperation

import libnacl


class DummyPolicy:
    """Policy to generate dummy data according to scenarios."""

    def __create_generic_facace(
        self,
        homedir: str,
        entity_data: dict,
        cls: type,
    ) -> bytes:
        """Generic entity facade generator."""
        secret = libnacl.secret.SecretBox().sk
        facade = Glue.run_async(cls.setup(
            homedir, secret, Const.A_ROLE_PRIMARY, entity_data))
        facade.archive(Const.CNL_VAULT).close()
        with open(os.path.join(homedir, 'secret.key', 'w')) as key:
            key.write(binascii.hexlify(secret).decode())
        return secret

    def create_person_facace(
        self,
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
        return self.__create_generic_facace(
            homedir, entity_data,
            PersonServerFacade if server else PersonClientFacade)

    def create_ministry_facade(
        self,
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
        return self.__create_generic_facace(
            homedir, entity_data,
            MinistryServerFacade if server else MinistryClientFacade)

    def create_church_facade(
        self,
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
        return self.__create_generic_facace(
            homedir, entity_data,
            ChurchServerFacade if server else ChurchClientFacade)

    def make_friends(self, facade, num):
        """Generate X number of friends and import to vault."""
        pass

    def make_churches(self, facade):
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

    async def make_community(self, facade: Facade):
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
