#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Random dummy data generators."""
import asyncio
import datetime
import functools
import io
import ipaddress
import os
import random
import string
import uuid
from tempfile import TemporaryDirectory

import libnacl
from libangelos.archive.portfolio_mixin import PortfolioMixin
from libangelos.const import Const
from libangelos.document.document import DocType
from libangelos.document.messages import Mail
from libangelos.facade.facade import Facade
from libangelos.misc import BaseDataClass, Misc
from libangelos.operation.setup import SetupPersonOperation, SetupMinistryOperation, SetupChurchOperation
from libangelos.policy.message import MessagePolicy, EnvelopePolicy
from libangelos.policy.portfolio import Portfolio, DOCUMENT_PATH, PortfolioPolicy, PGroup
from libangelos.policy.types import PersonData, MinistryData, ChurchData
from libangelos.policy.verify import StatementPolicy
from libangelos.task.task import TaskWaitress

from dummy.lipsum import (
    SURNAMES,
    MALE_NAMES,
    FEMALE_NAMES,
    LIPSUM_LINES,
    LIPSUM_WORDS,
    CHURCHES,
)
from dummy.stub import StubServer, StubClient


def run_async(coro):
    """Decorator for asynchronous test cases."""

    @functools.wraps(coro)
    def wrapper(*args, **kwargs):
        """Execute the coroutine with asyncio.run()"""
        return asyncio.run(coro(*args, **kwargs))

    return wrapper


def filesize(file):
    """Real file filesize reader."""
    if isinstance(file, io.IOBase):
        return os.fstat(file.fileno()).st_size
    else:
        return os.stat(file).st_size


class Generate:
    @staticmethod
    def person_data(num=1):
        """Generate random entity data for number of person entities."""
        identities = []
        for i in range(num):
            sex = random.choices(
                ["man", "woman", "undefined"], [0.495, 0.495, 0.01], k=1
            )[0]
            if sex == "man":
                names = random.choices(MALE_NAMES, k=random.randrange(2, 5))
            elif sex == "woman":
                names = random.choices(FEMALE_NAMES, k=random.randrange(2, 5))
            else:
                names = random.choices(
                    MALE_NAMES + FEMALE_NAMES, k=random.randrange(2, 5)
                )

            born = datetime.date.today() - datetime.timedelta(
                days=random.randrange(4748, 29220)
            )

            entity = PersonData()
            entity.given_name = names[0]
            entity.names = names
            entity.family_name = random.choices(SURNAMES, k=1)[0].capitalize()
            entity.sex = sex
            entity.born = born
            identities.append(entity)

        return identities

    @staticmethod
    def ministry_data(num=1):
        """Generate random entity data for number of ministry entities."""
        ministries = []
        for i in range(num):
            ministry = random.choices(LIPSUM_WORDS, k=random.randrange(3, 7))
            vision = random.choices(LIPSUM_WORDS, k=random.randrange(20, 25))
            founded = datetime.date.today() - datetime.timedelta(
                days=random.randrange(365, 29220)
            )

            entity = MinistryData()
            entity.ministry = " ".join(ministry).capitalize()
            entity.vision = " ".join(vision).capitalize()
            entity.founded = founded
            ministries.append(entity)

        return ministries

    @staticmethod
    def church_data(num=1):
        """Generate random entity data for number of church entities."""
        churches = []
        for i in range(num):
            church = random.choices(CHURCHES, k=1)[0]
            founded = datetime.date.today() - datetime.timedelta(
                days=random.randrange(730, 29220)
            )

            entity = ChurchData()
            entity.founded = founded
            entity.city = church[0]
            entity.region = church[1]
            entity.country = church[2]
            churches.append(entity)

        return churches

    @staticmethod
    def lipsum() -> bytes:
        """Random lipsum data generator."""
        return (
            "\n".join(random.choices(LIPSUM_LINES, k=random.randrange(1, 10)))
        ).encode("utf-8")

    @staticmethod
    def lipsum_sentence() -> str:
        """Random sentence"""
        return (
            " ".join(random.choices(LIPSUM_WORDS, k=random.randrange(3, 10)))
        ).capitalize()

    @staticmethod
    def filename(postfix=".txt"):
        """Random file name generator."""
        return (
                "".join(
                    random.choices(
                        string.ascii_lowercase + string.digits,
                        k=random.randrange(5, 10),
                    )
                )
                + postfix
        )

    @staticmethod
    def uuid():
        """Random uuid."""
        return uuid.uuid4()

    @staticmethod
    def ipv4():
        """Random uuid."""
        return ipaddress.IPv4Address(os.urandom(4))

    @staticmethod
    def new_secret() -> bytes:
        """Generate encryption key.

        Returns (bytes):
            Encryption key

        """
        return libnacl.secret.SecretBox().sk


class Introspection:
    """Facade introspection tools."""

    @staticmethod
    async def get_storage_portfolio_file_list(storage: PortfolioMixin, eid: uuid.UUID) -> set:
        """Create a set of all files in a portfolio stored in a storage"""
        dirname = storage.portfolio_path(eid)
        return await storage.archive.glob(name="{dir}/*".format(dir=dirname))

    @staticmethod
    def get_portfolio_file_list(storage: PortfolioMixin, portfolio: Portfolio):
        """Create a set of all filenames from a portfolio"""
        dirname = storage.portfolio_path(portfolio.entity.id)
        issuer, owner = portfolio.to_sets()
        return {DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id) for doc in issuer | owner}

    @staticmethod
    async def load_storage_file_list(storage: PortfolioMixin, file_list: set) -> set:
        """Load all files from a storage expecting them to be Documents and exist."""
        files = set()
        for filename in file_list:
            data = await storage.archive.load(filename)
            doc = PortfolioPolicy.deserialize(data)
            files.add(doc)

        return files


class ApplicationContext:
    """Environmental context for a stub application."""

    app = None
    dir = None
    secret = None

    def __init__(self, tmp_dir, secret, app):
        self.dir = tmp_dir
        self.secret = secret
        self.app = app

    @classmethod
    async def setup(cls, app_cls, data: BaseDataClass):
        secret = Generate.new_secret()
        tmp_dir = TemporaryDirectory()
        app = await app_cls.create(tmp_dir.name, secret, data)
        return cls(tmp_dir, secret, app)

    def __del__(self):
        if self.app:
            self.app.stop()
        self.dir.cleanup()


class StubMaker:
    """Maker of stubs."""

    TYPES = (
        (SetupPersonOperation, Generate.person_data),
        (SetupMinistryOperation, Generate.ministry_data),
        (SetupChurchOperation, Generate.church_data)
    )

    @classmethod
    async def __setup(cls, operation, generator, home, secret, server):
        return await Facade.setup(
            home,
            secret,
            Const.A_ROLE_PRIMARY,
            server,
            portfolio=operation.create(
                generator()[0],
                server=server)
        )

    @classmethod
    async def create_person_facace(cls, homedir: str, secret: bytes, server: bool = False) -> Facade:
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
        return await cls.__setup(
            SetupPersonOperation, Generate.person_data, homedir, secret, server)

    @classmethod
    async def create_ministry_facade(cls, homedir: str, secret: bytes, server: bool = False) -> Facade:
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
        return await cls.__setup(
            SetupMinistryOperation, Generate.ministry_data, homedir, secret, server)

    @classmethod
    async def create_church_facade(cls, homedir: str, secret: bytes, server: bool = True) -> bytes:
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
        return await cls.__setup(
            SetupChurchOperation, Generate.church_data, homedir, secret, server)

    @classmethod
    async def create_server(cls) -> ApplicationContext:
        return await ApplicationContext.setup(StubServer, Generate.church_data()[0])

    @classmethod
    async def create_client(cls) -> ApplicationContext:
        return await ApplicationContext.setup(StubClient, Generate.person_data()[0])


class Operations:
    """Application, facade and portfolio operations."""

    @staticmethod
    async def trust_mutual(f1: Facade, f2: Facade):
        """Make two facades mutually trust each other."""

        docs = set()
        docs.add(StatementPolicy.trusted(f1.data.portfolio, f2.data.portfolio))
        docs.add(StatementPolicy.trusted(f2.data.portfolio, f1.data.portfolio))

        await f1.storage.vault.add_portfolio(f2.data.portfolio.to_portfolio())
        await f2.storage.vault.add_portfolio(f1.data.portfolio.to_portfolio())

        await f1.storage.vault.docs_to_portfolio(docs)
        await f2.storage.vault.docs_to_portfolio(docs)

        await TaskWaitress().wait_for(f1.task.contact_sync)
        await TaskWaitress().wait_for(f2.task.contact_sync)

    @staticmethod
    async def send_mail(sender: Facade, recipient: Portfolio) -> Mail:
        """Generate one mail to recipient using a facade saving the mail to the outbox."""
        builder = MessagePolicy.mail(sender.data.portfolio, recipient)
        message = builder.message(Generate.lipsum_sentence(), Generate.lipsum().decode()).done()
        envelope = EnvelopePolicy.wrap(sender.data.portfolio, recipient, message)
        await sender.api.mailbox.save_outbox(envelope)
        return message

    @staticmethod
    async def inject_mail(server: Facade, sender: Facade, recipient: Portfolio) -> Mail:
        """Generate one mail to recipient using a facade injecting the mail to the server."""
        builder = MessagePolicy.mail(sender.data.portfolio, recipient)
        message = builder.message(Generate.lipsum_sentence(), Generate.lipsum().decode()).done()
        envelope = EnvelopePolicy.wrap(sender.data.portfolio, recipient, message)
        await server.storage.mail.save(
            DOCUMENT_PATH[DocType.COM_ENVELOPE].format(
                dir="", file=envelope.id
            ), envelope)
        return message

    @staticmethod
    async def portfolios(num: int, portfolio_list: list, server: bool = False, types: int = 0):
        """Generate random portfolios based on input data."""

        for person in StubMaker.TYPES[types][1](num):
            portfolio_list.append(StubMaker.TYPES[types][0].create(person, server=server))

    @staticmethod
    async def cross_authenticate(server: Facade, client: Facade, preselect: bool = True) -> bool:
        """Cross authenticate a server and a client.

        The facade will import each others portfolios, then they will trust each other and update the portfolios.
        Also the networks will be indexed at the client and the recent network preselected.
        When the client and server are cross authenticated, the client should be able to connect to the server.

        Args:
            server (Facade):
                Facade of the server
            client (Facade):
                Facade of the client
            preselect (bool):
                If the server should be the primary network in the client facade.

        Returns (bool):
            Whether the server is successfully indexed as a trusted network

        """
        # Client --> Server
        # Export the public client portfolio
        client_data = await client.storage.vault.load_portfolio(
            client.data.portfolio.entity.id, PGroup.SHARE_MAX_USER)

        # Add client portfolio to server
        await server.storage.vault.add_portfolio(client_data)

        # Load server data from server vault
        server_data = await server.storage.vault.load_portfolio(
            server.data.portfolio.entity.id, PGroup.SHARE_MAX_COMMUNITY)

        # Add server portfolio to client
        await client.storage.vault.add_portfolio(server_data)

        # Server -" Client
        # Trust the client portfolio
        trust = StatementPolicy.trusted(
            server.data.portfolio, client.data.portfolio)

        # Saving server trust for client to server
        await server.storage.vault.docs_to_portfolio(set([trust]))

        # Client <-- -" Server
        # Load client data from server vault
        client_data = await server.storage.vault.load_portfolio(
            client.data.portfolio.entity.id, PGroup.SHARE_MAX_USER)

        # Saving server trust for client to client
        await client.storage.vault.docs_to_portfolio(client_data.owner.trusted)

        # Client -" Server
        # Trust the server portfolio
        trust = StatementPolicy.trusted(client.data.portfolio, server.data.portfolio)

        # Saving client trust for server to client
        await client.storage.vault.docs_to_portfolio(set([trust]))

        # Client (index network)
        await TaskWaitress().wait_for(client.task.network_index)

        # Verify trusted network
        networks = {net[0] for net in await client.api.settings.networks() if net[1]}
        if str(server.data.portfolio.entity.id) not in networks:
            return False

        if preselect:
            client.data.client["CurrentNetwork"] = server.data.portfolio.entity.id
            await Misc.sleep()

        return True
