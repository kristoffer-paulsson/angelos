#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Dummy data generation utilities."""
import random

import libnacl
from libangelos.const import Const
from libangelos.document.document import DocType
from libangelos.facade.facade import Facade
from libangelos.operation.setup import SetupChurchOperation, SetupMinistryOperation
from libangelos.operation.setup import SetupPersonOperation
from libangelos.policy.domain import NetworkPolicy
from libangelos.policy.message import MessagePolicy, EnvelopePolicy
from libangelos.policy.portfolio import Portfolio, DOCUMENT_PATH
from libangelos.policy.verify import StatementPolicy

from .support import Generate, run_async


class DummyPolicy:
    """Policy to generate dummy data according to scenarios."""

    TYPES = (
        (SetupPersonOperation, Generate.person_data),
        (SetupMinistryOperation, Generate.ministry_data),
        (SetupChurchOperation, Generate.church_data)
    )

    @run_async
    async def __setup(self, operation, generator, home, secret, server):
        return await Facade.setup(
            home,
            secret,
            Const.A_ROLE_PRIMARY,
            server,
            portfolio=operation.create(
                generator()[0],
                server=server)
        )

    def new_secret(self) -> bytes:
        """Generate encryption key.

        Returns (bytes):
            Encryption key

        """
        return  libnacl.secret.SecretBox().sk

    def create_person_facace(self, homedir: str, secret: bytes, server: bool = False) -> Facade:
        """Generate random person facade.

        Args:
            homedir (str):
                The destination of the encrypted archives.
            secret (bytes):
                 Encryption key.
            server (bool):
                Generate a server of client, defaults to client.

        Returns (Facade):
            The generated facade instance.

        """
        return self.__setup(
            SetupPersonOperation, Generate.person_data, homedir, secret, server)


    def create_ministry_facade(self, homedir: str, secret: bytes, server: bool = False) -> Facade:
        """Generate random ministry facade.

        Args:
            homedir (str):
                The destination of the encrypted archives.
            secret (bytes):
                 Encryption key.
            server (bool):
                Generate a server of client, defaults to client.

        Returns (Facade):
            The generated facade instance.

        """
        return self.__setup(
            SetupMinistryOperation, Generate.ministry_data, homedir, secret, server)

    def create_church_facade(self, homedir: str, secret: bytes, server: bool = True) -> bytes:
        """Generate random church facade.

        Args:
            homedir (str):
                The destination of the encrypted archives.
            secret (bytes):
                 Encryption key.
            server (bool):
                Generate a server of client, defaults to client.

        Returns (Facade):
            The generated facade instance.

        """
        return self.__setup(
            SetupChurchOperation, Generate.church_data, homedir, secret, server)

    @run_async
    async def make_mail(self, facade: Facade, sender: Portfolio, inbox: bool=True, num: int=1):
        """Generate X number of mails from sender within facade.

        Args:
            facade (Facade):
                Facade to send random dummy mails to .
            sender (Portfolio):
                Senders portfolio.
            num (int):
                Numbers of mail to generate.

        """
        for _ in range(num):
            envelope = EnvelopePolicy.wrap(
                sender,
                facade.data.portfolio,
                MessagePolicy.mail(sender, facade.data.portfolio).message(
                    Generate.filename(postfix="."),
                    Generate.lipsum_sentence().decode(),
                ).done(),
            )
            if inbox:
                await facade.api.mailbox.import_envelope(envelope)
            else:
                filename = DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                    dir="/", file=envelope.id
                )
                await facade.api.mail.save(filename, envelope)