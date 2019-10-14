# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import os
import copy
import uuid
import logging
import asyncio

from typing import Sequence, Set, List, Tuple

from .mail import MailAPI
from .settings import SettingsAPI
from .replication import ReplicationAPI
from ..const import Const

from ..document import (
    Document,
    Person,
    Ministry,
    Church,
    Trusted,
    Verified,
    Revoked,
)
from ..archive.archive7 import Archive7
from ..archive.vault import Vault
from ..archive.mail import Mail
from ..archive.helper import Glue
from ..policy import (
    PrivatePortfolio,
    Portfolio,
    ImportUpdatePolicy,
    ImportPolicy,
    NetworkPolicy,
    EntityData,
    PGroup,
    DOCUMENT_PATH,
    DocSet,
)

from ..operation.setup import (
    SetupPersonOperation,
    SetupMinistryOperation,
    SetupChurchOperation,
)
from ..data.vars import PREFERENCES_INI


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
                os.path.join(home_dir, Const.CNL_VAULT), secret
            )

    @classmethod
    async def setup(
        cls,
        home_dir: str,
        secret: bytes,
        role: int,
        entity_data: EntityData = None,
        portfolio: PrivatePortfolio = None,
    ):
        """Create the existence of a new facade from scratch."""

        if entity_data and portfolio:
            raise ValueError("Either entity_data or portfolio, not both")

        logging.info("Setting up facade of type: %s" % type(cls))

        if not os.path.isdir(home_dir):
            RuntimeError("Home directory doesn't exist")

        if role not in [Const.A_ROLE_PRIMARY, Const.A_ROLE_BACKUP, 0]:
            RuntimeError("Unsupported use of facade")

        if entity_data:
            server = (
                True
                if cls.INFO[0]
                in (
                    Const.A_TYPE_PERSON_SERVER,
                    Const.A_TYPE_MINISTRY_SERVER,
                    Const.A_TYPE_CHURCH_SERVER,
                )
                else False
            )

            if role is Const.A_ROLE_BACKUP:
                role_str = "backup"
            elif role is Const.A_ROLE_PRIMARY and server:
                role_str = "server"
            else:
                role_str = "client"

            portfolio = cls.PREFS[1].create(entity_data, role_str, server)

            if server:
                NetworkPolicy.generate(portfolio)
                # Setting up server specific archives
                Mail.setup(
                    os.path.join(home_dir, Const.CNL_MAIL),
                    secret,
                    portfolio,
                    _type=cls.INFO[0],
                    role=Const.A_ROLE_PRIMARY,
                    use=Const.A_USE_MAIL,
                ).close()

        if not cls.PREFS[1].import_ext(portfolio, role_str, server):
            raise ValueError("Failed importing portfolio to new facade")

        vault = Vault.setup(
            os.path.join(home_dir, Const.CNL_VAULT),
            secret,
            portfolio,
            _type=cls.INFO[0],
            role=role,
            use=Const.A_USE_VAULT,
        )

        await vault.save_settings("preferences.ini", PREFERENCES_INI)

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
            raise RuntimeError("Unkown archive type: %s" % str(_type))

        await facade._post_init()
        return facade

    def archive(self, archive: str) -> Archive7:
        """Return available archive based on CNL constant."""
        try:
            if archive == Const.CNL_VAULT:
                return self._vault
            elif archive == Const.CNL_MAIL:
                return self._mail
            else:
                return None
        except AttributeError:
            logging.exception(
                "Archive attribute %s not implemented." % archive
            )
            return None

    async def _post_init(self):
        """Load private portfolio for facade."""
        server = (
            True
            if self._vault.stats.type
            in (
                Const.A_TYPE_PERSON_SERVER,
                Const.A_TYPE_MINISTRY_SERVER,
                Const.A_TYPE_CHURCH_SERVER,
            )
            else False
        )

        self.__portfolio = await self._vault.load_portfolio(
            self._vault.stats.owner, PGroup.SERVER if server else PGroup.CLIENT
        )
        self.__mail = MailAPI(self.__portfolio, self._vault)
        self.__settings = SettingsAPI(self.__portfolio, self._vault)
        self.__replication = ReplicationAPI(self)

    async def load_portfolio(
        self, eid: uuid.UUID, conf: Sequence[str]
    ) -> Portfolio:
        """Load a portfolio belonging to id according to configuration."""
        return await self._vault.load_portfolio(eid, conf)

    async def update_portfolio(
        self, portfolio: Portfolio
    ) -> (bool, Set[Document], Set[Document]):
        """Update a portfolio by comparison."""
        old = await self._vault.load_portfolio(portfolio.entity.id, PGroup.ALL)

        issuer, owner = portfolio.to_sets()
        new_set = issuer | owner

        issuer, owner = old.to_sets()
        old_set = issuer | owner

        newdoc = set()
        upddoc = set()
        for ndoc in new_set:  # Find documents that are new or changed.
            newone = True
            updone = False
            for odoc in old_set:
                if ndoc.id == odoc.id:
                    newone = False
                    if ndoc.expires != odoc.expires:
                        updone = True
            if newone:
                newdoc.add(ndoc)
            elif updone:
                upddoc.add(ndoc)

        new = Portfolio()
        new.from_sets(newdoc | upddoc, newdoc | upddoc)
        rejected = set()

        # Validating any new keys
        imp_policy = ImportPolicy(old)
        upd_policy = ImportUpdatePolicy(old)
        if new.keys and old.keys:
            for key in new.keys:
                reject = set()
                if not upd_policy.keys(key):
                    rejected.add(key)
            new.keys -= reject
            old.keys += new.keys  # Adding new keys to old portfolio,
            # this way the old portfolio can verify documents signed with
            # new keys.
            rejected |= reject

        # Validating any new entity
        if new.entity and old.entity:
            if not upd_policy.entity(new.entity):
                new.entity = None

        # Adding old entity and keys if none.
        if not new.entity:
            new.entity = old.entity
        if not new.keys:
            new.keys = old.keys

        if new.profile:
            if not imp_policy.issued_document(new.profile):
                rejected.add(new.profile)
                new.profile = None
        if new.network:
            if not imp_policy.issued_document(new.network):
                rejected.add(new.network)
                new.network = None

        if new.issuer.verified:
            for verified in new.issuer.verified:
                rejected = set()
                if not imp_policy.issued_document(verified):
                    reject.add(verified)
            new.issuer.verified -= reject
            rejected |= reject
        if new.issuer.trusted:
            for trusted in new.issuer.trusted:
                reject = set()
                if not imp_policy.issued_document(trusted):
                    rejected.add(trusted)
            new.issuer.trusted -= reject
            rejected |= reject
        if new.issuer.revoked:
            for revoked in new.issuer.revoked:
                reject = set()
                if not imp_policy.issued_document(revoked):
                    rejected.add(revoked)
            new.issuer.revoked -= reject
            rejected |= reject

        removed = (
            portfolio.owner.revoked
            | portfolio.owner.trusted
            | portfolio.owner.verified
        )

        # Really remove files that can't be verified
        portfolio.owner.revoked = set()
        portfolio.owner.trusted = set()
        portfolio.owner.verified = set()

        if hasattr(new, "privkeys"):
            if new.privkeys:
                if not imp_policy.issued_document(new.privkeys):
                    new.privkeys = None
        if hasattr(new, "domain"):
            if new.domain:
                if not imp_policy.issued_document(new.domain):
                    new.domain = None
        if hasattr(new, "nodes"):
            if new.nodes:
                for node in new.nodes:
                    reject = set()
                    if not imp_policy.node_document(node):
                        reject.add(node)
                new.nodes -= reject
                rejected |= reject

        return await self._vault.save_portfolio(new), rejected, removed

    async def import_portfolio(
        self, portfolio: Portfolio
    ) -> (bool, Set[Document], Set[Document]):
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
            logging.error("Portfolio entity and keys doesn't validate")
            return False, None, None

        rejected |= policy._filter_set(portfolio.keys)
        portfolio.keys.add(keys)

        if portfolio.profile and not policy.issued_document(portfolio.profile):
            rejected.add(portfolio.profile)
            portfolio.profile = None
            logging.warning("Removed invalid profile from portfolio")

        if portfolio.network and not policy.issued_document(portfolio.network):
            rejected.add(portfolio.network)
            portfolio.network = None
            logging.warning("Removed invalid network from portfolio")

        rejected |= policy._filter_set(portfolio.issuer.revoked)
        rejected |= policy._filter_set(portfolio.issuer.verified)
        rejected |= policy._filter_set(portfolio.issuer.trusted)

        if isinstance(portfolio, PrivatePortfolio):
            if portfolio.privkeys and not policy.issued_document(
                portfolio.privkeys
            ):
                rejected.add(portfolio.privkeys)
                portfolio.privkeys = None
                logging.warning("Removed invalid private keys from portfolio")

            if portfolio.domain and not policy.issued_document(
                portfolio.domain
            ):
                rejected.add(portfolio.domain)
                portfolio.domain = None
                logging.warning("Removed invalid domain from portfolio")

            for node in portfolio.nodes:
                if node and not policy.node_document(node):
                    rejected.add(node)
                    portfolio.nodes.remove(node)
                    logging.warning("Removed invalid node from portfolio")

        removed = (
            portfolio.owner.revoked
            | portfolio.owner.trusted
            | portfolio.owner.verified
        )

        # Really remove files that can't be verified
        portfolio.owner.revoked = set()
        portfolio.owner.trusted = set()
        portfolio.owner.verified = set()

        result = await self._vault.new_portfolio(portfolio)
        return result, rejected, removed

    async def docs_to_portfolios(
        self, documents: Set[Document]
    ) -> Set[Document]:
        """import loose documents into a portfolio, (Statements)."""
        documents = DocSet(documents)
        rejected = set()

        ops = []
        for issuer_id in documents.issuers():
            policy = ImportPolicy(
                await self._vault.load_portfolio(
                    issuer_id, PGroup.VERIFIER_REVOKED
                )
            )
            for document in documents.get_issuer(issuer_id):
                if not isinstance(document, (Trusted, Verified, Revoked)):
                    raise TypeError("Document must be subtype of Statement")
                if policy.issued_document(document):
                    ops.append(
                        self._vault.save(
                            DOCUMENT_PATH[document.type].format(
                                dir="/portfolios/{0}".format(document.owner),
                                file=document.id,
                            ),
                            document,
                        )
                    )
                else:
                    rejected.add(document)

        result = await asyncio.gather(*ops, return_exceptions=True)
        return rejected, result

    async def list_portfolios(
        self, query: str = "*"
    ) -> List[Tuple[bytes, Exception]]:
        """List all portfolio entities."""
        doclist = await self._vault.search(
            path="/portfolios/{0}.ent".format(query), limit=100
        )
        result = Glue.doc_validate_report(doclist, (Person, Ministry, Church))
        return result

    @property
    def portfolio(self):
        """Private portfolio getter."""
        return self.__portfolio

    @property
    def mail(self):
        """Mail interface getter."""
        return self.__mail

    @property
    def settings(self):
        """Settings interface getter."""
        return self.__settings

    @property
    def replication(self):
        """Replication interface getter."""
        return self.__replication


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

        self._mail = Mail(
            os.path.join(self._path, Const.CNL_MAIL), self._secret
        )

    async def _post_init(self):
        """Post init async work."""
        pass


class ClientFacadeMixin(TypeFacadeMixin):
    """Mixin for a Church Facade."""

    def __init__(self):
        TypeFacadeMixin.__init__(self)

    async def _post_init(self):
        """Post init async work."""
        pass


class PersonClientFacade(Facade, ClientFacadeMixin, PersonFacadeMixin):
    """Final facade for Person entity in a client."""

    INFO = (Const.A_TYPE_PERSON_CLIENT,)

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

    INFO = (Const.A_TYPE_PERSON_SERVER,)

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

    INFO = (Const.A_TYPE_MINISTRY_CLIENT,)

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

    INFO = (Const.A_TYPE_MINISTRY_SERVER,)

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

    INFO = (Const.A_TYPE_CHURCH_CLIENT,)

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

    INFO = (Const.A_TYPE_CHURCH_SERVER,)

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
