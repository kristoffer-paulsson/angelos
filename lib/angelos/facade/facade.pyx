# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring.
"""
import os
import copy
import uuid
import logging
import asyncio

from typing import Sequence, Set

from ..const import Const

from ..document import (
    Document, Person, Ministry, Church, Keys, Node, Network, Envelope, Trusted,
    Verified)
from ..archive.vault import Vault
from ..archive.helper import Glue
from ..policy import (
    PrivatePortfolio, Portfolio, ImportUpdatePolicy, ImportPolicy,
    NetworkPolicy, EntityData, PGroup, DOCUMENT_PATH)

from ..operation.setup import (
    SetupPersonOperation, SetupMinistryOperation, SetupChurchOperation)


class Facade:
    """
    Facade baseclass.

    The Facade is the gatekeeper of the integrity. The facade garantuees the
    integrity of the entity and its domain. It is here where all policies are
    enforced and where security is checked. No document can be imported without
    being verified.
    """

    def __init__(self, home_dir, secret, vault=None):
        """
        Initialize the facade class.

        Opens the Vault with the secret key and loads the core documents.
        """
        self._path = home_dir
        self._secret = secret

        if isinstance(vault, Vault):
            self._vault = vault
        else:
            self._vault = Vault(
                os.path.join(home_dir, Const.CNL_VAULT), secret)

    @classmethod
    async def setup(cls, home_dir: str, secret: bytes, role: int,
                    entity_data: EntityData=None,
                    portfolio: PrivatePortfolio=None):
        """Create the existence of a new facade from scratch."""

        if entity_data and portfolio:
            raise ValueError('Either entity_data or portfolio, not both')

        logging.info('Setting up facade of type: %s' % type(cls))

        if not os.path.isdir(home_dir):
            RuntimeError('Home directory doesn\'t exist')

        if role not in [Const.A_ROLE_PRIMARY, Const.A_ROLE_BACKUP, 0]:
            RuntimeError('Unsupported use of facade')

        if entity_data:
            server = True if cls.INFO[0] in (
                Const.A_TYPE_PERSON_SERVER,
                Const.A_TYPE_MINISTRY_SERVER,
                Const.A_TYPE_CHURCH_SERVER
            ) else False

            if role is Const.A_ROLE_BACKUP:
                role_str = 'backup'
            elif role is Const.A_ROLE_PRIMARY and server:
                role_str = 'server'
            else:
                role_str = 'client'

            portfolio = cls.PREFS[1].create(entity_data, role_str, server)

            if server:
                NetworkPolicy.generate(portfolio)

        if not cls.PREFS[1].import_ext(portfolio, role_str, server):
            raise ValueError('Failed importing portfolio to new facade')

        vault = Vault.setup(
            os.path.join(home_dir, Const.CNL_VAULT), secret, portfolio,
            _type=cls.INFO[0], role=role, use=Const.A_USE_VAULT)

        await vault.new_portfolio(portfolio)

        facade = cls(home_dir, secret, vault)
        await facade._post_init()
        return facade

    @staticmethod
    async def open(home_dir, secret):
        """
        Load an existing facade.

        The Vault is opened before the creation of the Facade so the right sort
        can be instanciated.
        """
        vault = Vault(os.path.join(home_dir, Const.CNL_VAULT), secret)
        _type = vault.stats.type

        if _type == Const.A_TYPE_PERSON_CLIENT:
            facade = PersonClientFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_PERSON_SERVER:
            facade = PersonServerFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_MINISTRY_CLIENT:
            facade = MinistryClientFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_MINISTRY_SERVER:
            facade = MinistryServerFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_CHURCH_CLIENT:
            facade = ChurchClientFacade(home_dir, secret, vault)
        elif _type == Const.A_TYPE_CHURCH_SERVER:
            facade = ChurchServerFacade(home_dir, secret, vault)
        else:
            raise RuntimeError('Unkown archive type: %s' % str(_type))

        await facade._post_init()
        return facade

    async def _post_init(self):
        """Load private portfolio for facade."""
        server = True if self._vault.stats.type in (
            Const.A_TYPE_PERSON_SERVER,
            Const.A_TYPE_MINISTRY_SERVER,
            Const.A_TYPE_CHURCH_SERVER
        ) else False

        self.__portfolio = await self._vault.load_portfolio(
            self._vault.stats.owner,
            PGroup.SERVER if server else PGroup.CLIENT)

    async def load_portfolio(
            self, id: uuid.UUID, conf: Sequence[str]) -> Portfolio:
        """Load a portfolio belonging to id according to configuration."""
        return await self._vault.load_portfolio(id, conf)

    def update_portfolio(self, portfolio: Portfolio) -> bool:
        """Update a portfolio by comparison."""
        raise NotImplementedError()

    async def import_portfolio(
            self, portfolio: Portfolio) -> (
                bool, Set[Document], Set[Document]):
        """
        Import a portfolio of douments into the vault.

        All policies are being applied, invalid documents or documents that
        require extra portfolios for validation are rejected. That includes
        the owner documents.

        Return wether portfolio was imported True/False and rejected documents
        and removed documents.
        """
        rejected = set()
        portfolio = copy.copy(portfolio)
        policy = ImportPolicy(portfolio)

        entity, keys = policy.entity()
        if (entity, keys) == (None, None):
            logging.error('Portfolio entity and keys doesn\'t validate')
            return False, None, None

        rejected |= policy._filter_set(portfolio.keys)
        portfolio.keys.add(keys)

        if portfolio.profile and not policy.issued_document(portfolio.profile):
            rejected.add(portfolio.profile)
            portfolio.profile = None
            logging.warning('Removed invalid profile from portfolio')

        if portfolio.network and not policy.issued_document(portfolio.network):
            rejected.add(portfolio.network)
            portfolio.network = None
            logging.warning('Removed invalid network from portfolio')

        rejected |= policy._filter_set(portfolio.issuer.revoked)
        rejected |= policy._filter_set(portfolio.issuer.verified)
        rejected |= policy._filter_set(portfolio.issuer.trusted)

        if isinstance(portfolio, PrivatePortfolio):
            if portfolio.privkeys and not policy.issued_document(
                    portfolio.privkeys):
                rejected.add(portfolio.privkeys)
                portfolio.privkeys = None
                logging.warning('Removed invalid private keys from portfolio')

            if portfolio.domain and not policy.issued_document(
                    portfolio.domain):
                rejected.add(portfolio.domain)
                portfolio.domain = None
                logging.warning('Removed invalid domain from portfolio')

            rejected |= policy._filter_set(portfolio.nodes)

        removed = (
            portfolio.owner.revoked | portfolio.owner.trusted |
            portfolio.owner.verified)

        print(portfolio.entity.id)
        result = await self._vault.new_portfolio(portfolio)
        return result, rejected, removed

    async def docs_to_portfolio(
            self, portfolio: uuid.UUID,
            documents: Sequence[Document]) -> Set[Document]:
        """import loose documents into a portfolio, (Statements)."""
        if portfolio.int == self.portfolio.entity.id.int:
            portfolio = self.portfolio
        else:
            portfolio = await self._vault.load_portfolio(
                portfolio, PGroup.VERIFIER)

        policy = ImportPolicy(portfolio)
        issuer = await self._vault.load_portfolio(
            next(iter(documents)).issuer, PGroup.VERIFIER_REVOKED)
        save = set()
        rejected = set()

        for document in sorted(documents, key=lambda doc: doc.issuer.int):
            if not isinstance(document, (Trusted, Verified)):
                raise TypeError('Document must be of type Trusted or Verified')
            if issuer.entity.id != document.issuer:
                issuer = await self._vault.load_portfolio(
                    document.issuer, PGroup.VERIFIER_REVOKED)

            result = policy.owned_document(issuer, document)
            if result:
                save.add(document)
            else:
                rejected.add(document)

        for document in save:
            await self._vault.save(DOCUMENT_PATH[document.type].format(
                dir='/portfolio/{0}'.format(document.owner),
                file=document.id), document)

        return rejected

    @property
    def portfolio(self):
        """Private portfolio getter."""
        return self.__portfolio

    @property
    def mail(self):
        """Mail interface getter."""
        return self.__mail

    def import_entity(self, entity, keys):
        """
        Import an entity.

        Import a foreign entity and its public keys. Enforces
        ImportEntityPolicy.
        """
        valid = True
        dir = None
        policy = ImportPolicy()
        if isinstance(entity, Person):
            valid = policy.person(entity, keys)
            dir = '/entities/persons'
        elif isinstance(entity, Ministry):
            valid = policy.ministry(entity, keys)
            dir = '/entities/ministries'
        elif isinstance(entity, Church):
            valid = policy.church(entity, keys)
            dir = '/entities/churches'
        else:
            logging.warning('Invalid entity type')
            raise TypeError('Invalid entity type')

        if not valid:
            logging.info('Entity or Keys are invalid')
            raise RuntimeError('Entity or Keys are invalid')
        else:
            Glue.run_async(
                self._vault.save(os.path.join(
                    dir, str(entity.id) + '.pickle'), entity),
                self._vault.save(os.path.join(
                    '/keys', str(keys.id) + '.pickle'), keys)
            )

            return True

    def update_keys(self, newkeys):
        """
        Import new public keys.

        Imports new public keys for already imported foreign entity. Enforces
        ImportUpdatePolicy.
        """
        entity = self.find_entity(newkeys.issuer)
        keylist = self.find_keys(newkeys.issuer)

        valid = False
        for keys in keylist:
            policy = ImportUpdatePolicy(entity, keys)
            if policy.keys(newkeys):
                valid = True
                break

        if valid:
            result = asyncio.get_event_loop().run_until_complete(
                self._vault.save(os.path.join(
                    '/keys', str(newkeys.id) + '.pickle'), newkeys))
            if isinstance(result, Exception):
                raise result
            logging.info('New keys imported')
            return True
        else:
            logging.error('New keys invalid')
            return False

    def update_entity(self, entity):
        """
        Import updated entity document.

        Imports an updated version for already imported foreign entity.
        Enforces ImportUpdatePolicy.
        """
        old_ent = self.find_entity(entity.id)
        keylist = self.find_keys(entity.id)

        dir = None
        if isinstance(entity, Person):
            dir = '/entities/persons'
        elif isinstance(entity, Ministry):
            dir = '/entities/ministries'
        elif isinstance(entity, Church):
            dir = '/entities/churches'
        else:
            logging.warning('Invalid entity type')
            raise TypeError('Invalid entity type')

        valid = False
        for keys in keylist:
            policy = ImportUpdatePolicy(old_ent, keys)
            if policy.entity(entity):
                valid = True
                break

        if valid:
            result = asyncio.get_event_loop().run_until_complete(
                self._vault.update(os.path.join(
                    dir, str(entity.id) + '.pickle'), entity))
            if isinstance(result, Exception):
                raise result
            logging.info('updated entity imported')
            return True
        else:
            logging.error('Updated entity invalid')
            return False

    def find_keys(self, issuer, expiry_check=True):
        """
        Load public keys.

        Loads public keys belonging to issuing entity.
        """
        doclist = Glue.run_async(self._vault.issuer(issuer, '/keys/', 10))
        return Glue.doc_check(doclist, Keys, expiry_check)

    def find_entity(self, issuer, expiry_check=True):
        """
        Load foreign entity document.

        Loads the entity document based on the issuers ID.
        """
        doclist = Glue.run_async(self._vault.issuer(issuer, '/entities/*', 1))
        entitylist = Glue.doc_check(
            doclist, (Person, Ministry, Church), expiry_check)

        return entitylist[0] if len(entitylist) else None


class EntityFacadeMixin:
    """Abstract baseclass for Entities FacadeMixin's"""

    PREFS = (None, None)


class PersonFacadeMixin(EntityFacadeMixin):
    """Mixin for a Person Facade."""

    PREFS = (Person, SetupPersonOperation)

    def __init__(self):
        EntityFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        pass


class MinistryFacadeMixin(EntityFacadeMixin):
    """Mixin for a Ministry Facade."""

    PREFS = (Ministry, SetupMinistryOperation)

    def __init__(self):
        EntityFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        pass


class ChurchFacadeMixin(EntityFacadeMixin):
    """Mixin for a Church Facade."""

    PREFS = (Church, SetupChurchOperation)

    def __init__(self):
        EntityFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        pass


class TypeFacadeMixin:
    pass


class ServerFacadeMixin(TypeFacadeMixin):
    """Mixin for a Server Facade."""

    def __init__(self):
        TypeFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        pass

    async def load_client_auth(self, username):
        """Load documents required for Clients server authentication."""
        issuer = uuid.UUID(username)
        doclist = Glue.run_async(
            self._vault.issuer(issuer, '/keys/', 3),
            self._vault.issuer(issuer, '/entities/*', 1),
            self._vault.issuer(issuer, '/issued/trusted', 1)
        )

        authlist = (
            Glue.doc_check(doclist[0], Keys, True),
            Glue.doc_check(doclist[1], (Person, Ministry, Church), True),
            Glue.doc_check(doclist[2], Trusted, True)
        )

        return authlist if len(authlist) else None

    async def load_host_auth(self, username):
        """Load documents required for Hosts server authentication."""
        issuer = uuid.UUID(username)
        doclist = Glue.run_async(
            self._vault.issuer(issuer, '/networks/', 1),
            self._vault.issuer(issuer, '/keys/', 2),
            self._vault.issuer(issuer, '/entities/*', 1),
            self._vault.issuer(issuer, '/issued/trusted', 1)
        )

        authlist = (
            Glue.doc_check(doclist[1], Keys, True),
            Glue.doc_check(doclist[2], (Person, Ministry, Church), True),
            Glue.doc_check(doclist[3], Trusted, True),
            Glue.doc_check(doclist[0], Network, True),
        )

        return authlist if len(authlist) else None

    async def load_node_auth(self, username):
        """Load documents required for Nodes server authentication."""
        issuer = uuid.UUID(username)
        doclist = Glue.run_async(
            self._vault.issuer(
                issuer, '/settings/nodes' + str(issuer)+'.pickle', 1))

        authlist = (Glue.doc_check(doclist[0], Node, True))
        return authlist if len(authlist) else None


class ClientFacadeMixin(TypeFacadeMixin):
    """Mixin for a Church Facade."""

    def __init__(self):
        TypeFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        pass

    def load_inbox(self):
        doclist = Glue.run_async(
            self._vault.search(path=Vault.INBOX, limit=100))
        result = Glue.doc_validate_report(doclist, Envelope)
        return result


class PersonClientFacade(Facade, ClientFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity in a client."""

    INFO = (Const.A_TYPE_PERSON_CLIENT, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        await Facade._post_init(self)
        await ClientFacadeMixin._post_init(self)
        await PersonFacadeMixin._post_init(self)


class PersonServerFacade(Facade, ServerFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity as a server."""

    INFO = (Const.A_TYPE_PERSON_SERVER, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        PersonFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        await Facade._post_init(self)
        await ServerFacadeMixin._post_init(self)
        await PersonFacadeMixin._post_init(self)


class MinistryClientFacade(Facade, ClientFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity in a client."""

    INFO = (Const.A_TYPE_MINISTRY_CLIENT, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        await Facade._post_init(self)
        await ClientFacadeMixin._post_init(self)
        await MinistryFacadeMixin._post_init(self)


class MinistryServerFacade(Facade, ServerFacadeMixin, MinistryFacadeMixin):
    """Final facade for Ministry entity as a server."""

    INFO = (Const.A_TYPE_MINISTRY_SERVER, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        MinistryFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        await Facade._post_init(self)
        await ServerFacadeMixin._post_init(self)
        await MinistryFacadeMixin._post_init(self)


class ChurchClientFacade(Facade, ClientFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity in a client."""

    INFO = (Const.A_TYPE_CHURCH_CLIENT, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ClientFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        await Facade._post_init(self)
        await ClientFacadeMixin._post_init(self)
        await ChurchFacadeMixin._post_init(self)


class ChurchServerFacade(Facade, ServerFacadeMixin, ChurchFacadeMixin):
    """Final facade for Church entity as a server."""

    INFO = (Const.A_TYPE_CHURCH_SERVER, )

    def __init__(self, home_dir, secret, vault=None):
        """Initialize the facade and its mixins."""
        Facade.__init__(self, home_dir, secret, vault)
        ServerFacadeMixin.__init__(self)
        ChurchFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        await Facade._post_init(self)
        await ServerFacadeMixin._post_init(self)
        await ChurchFacadeMixin._post_init(self)
