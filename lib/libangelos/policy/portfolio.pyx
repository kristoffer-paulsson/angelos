# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Policy classes for document portfolios."""
import collections
import pprint
import uuid
from collections.abc import Iterable
from dataclasses import dataclass
from typing import Set, Tuple

import msgpack
from libangelos.document.document import DocType, Document
from libangelos.document.domain import Domain, Node, Network
from libangelos.document.entities import Person, Ministry, Church, PrivateKeys, Keys
from libangelos.document.envelope import Envelope
from libangelos.document.messages import Note, Instant, Mail, Share, Report
from libangelos.document.misc import StoredLetter
from libangelos.document.profiles import PersonProfile, MinistryProfile, ChurchProfile
from libangelos.document.statements import Verified, Trusted, Revoked
from libangelos.document.types import EntityT, ProfileT, DocumentT
from libangelos.policy.types import PortfolioABC, PrivatePortfolioABC

from libangelos.validation import BaseValidator


class PField:
    """Definition of portfolio fields."""

    ENTITY = "entity"
    PROFILE = "profile"
    PRIVKEYS = "privkeys"
    KEYS = "keys"
    DOMAIN = "domain"
    NODE = "node"
    NODES = "nodes"
    NET = "network"

    ISSUER_VERIFIED = "issuer.verified"
    ISSUER_TRUSTED = "issuer.trusted"
    ISSUER_REVOKED = "issuer.revoked"

    OWNER_VERIFIED = "owner.verified"
    OWNER_TRUSTED = "owner.trusted"
    OWNER_REVOKED = "owner.revoked"


class PGroup:
    """Definitions of different sets of documents for different purposes."""

    # Basic set for verifying documents
    VERIFIER = (PField.ENTITY, PField.KEYS)
    # Set for verifying documents and check revoked documents
    VERIFIER_REVOKED = (PField.ENTITY, PField.KEYS, PField.ISSUER_REVOKED)
    # Basic set for signing documents
    SIGNER = (PField.ENTITY, PField.PRIVKEYS, PField.KEYS)
    # Basic set for running Client Facade
    CLIENT = (
        PField.ENTITY,
        PField.PRIVKEYS,
        PField.KEYS,
        PField.DOMAIN,
        PField.NODES,
    )
    # Basic set for running Server Facade
    SERVER = (
        PField.ENTITY,
        PField.PRIVKEYS,
        PField.KEYS,
        PField.DOMAIN,
        PField.NODES,
        PField.NET,
    )
    # Necessary set for server authentication
    CLIENT_AUTH = (
        PField.ENTITY,
        PField.KEYS,
        PField.NET,
        PField.OWNER_VERIFIED,
        PField.OWNER_TRUSTED,
    )
    # Documents issued by issuer
    ISSUER = (
        PField.ISSUER_VERIFIED,
        PField.ISSUER_TRUSTED,
        PField.ISSUER_REVOKED,
    )
    # Documents issued by others
    OWNER = (PField.OWNER_VERIFIED, PField.OWNER_TRUSTED, PField.OWNER_REVOKED)
    # Minimum set for sharing identity
    SHARE_MIN_USER = (PField.ENTITY, PField.KEYS)
    # Minimum set for sharing community
    SHARE_MIN_COMMUNITY = (PField.ENTITY, PField.KEYS, PField.NET)
    # Medium set for sharing identity
    SHARE_MED_USER = (PField.ENTITY, PField.PROFILE, PField.KEYS)
    # Medium set for sharing community
    SHARE_MED_COMMUNITY = (
        PField.ENTITY,
        PField.PROFILE,
        PField.KEYS,
        PField.NET,
    )
    # Maximum set for sharing identity
    SHARE_MAX_USER = (
        PField.ENTITY,
        PField.PROFILE,
        PField.KEYS,
        PField.OWNER_VERIFIED,
        PField.OWNER_TRUSTED,
    )
    # Maximum set for sharing community
    SHARE_MAX_COMMUNITY = (
        PField.ENTITY,
        PField.PROFILE,
        PField.KEYS,
        PField.NET,
        PField.OWNER_VERIFIED,
        PField.OWNER_TRUSTED,
    )
    # Complete set of documents of all types
    ALL = (
        PField.ENTITY,
        PField.PROFILE,
        PField.PRIVKEYS,
        PField.KEYS,
        PField.DOMAIN,
        PField.NODE,
        PField.NODES,
        PField.NET,
        PField.ISSUER_VERIFIED,
        PField.ISSUER_TRUSTED,
        PField.ISSUER_REVOKED,
        PField.OWNER_VERIFIED,
        PField.OWNER_TRUSTED,
        PField.OWNER_REVOKED,
    )


PORTFOLIO_TEMPLATE = {
    PField.ENTITY: "{dir}/{file}.ent",
    PField.PROFILE: "{dir}/{file}.pfl",
    PField.PRIVKEYS: "{dir}/{file}.pky",
    PField.KEYS: "{dir}/{file}.key",
    PField.DOMAIN: "{dir}/{file}.dmn",
    PField.NODES: "{dir}/{file}.nod",
    PField.NET: "{dir}/{file}.net",
    PField.ISSUER_VERIFIED: "{dir}/{file}.ver",
    PField.ISSUER_TRUSTED: "{dir}/{file}.rst",
    PField.ISSUER_REVOKED: "{dir}/{file}.rev",
    PField.OWNER_VERIFIED: "{dir}/{file}.ver",
    PField.OWNER_TRUSTED: "{dir}/{file}.rst",
    PField.OWNER_REVOKED: "{dir}/{file}.rev",
}

PORTFOLIO_PATTERN = {
    PField.ENTITY: ".ent",
    PField.PROFILE: ".pfl",
    PField.PRIVKEYS: ".pky",
    PField.KEYS: ".key",
    PField.DOMAIN: ".dmn",
    PField.NODES: ".nod",
    PField.NODE: ".nod",
    PField.NET: ".net",
    PField.ISSUER_VERIFIED: ".ver",
    PField.ISSUER_TRUSTED: ".rst",
    PField.ISSUER_REVOKED: ".rev",
    PField.OWNER_VERIFIED: ".ver",
    PField.OWNER_TRUSTED: ".rst",
    PField.OWNER_REVOKED: ".rev",
}

PORTFOLIO_TYPE = {
    PField.ENTITY: (Person, Ministry, Church),
    PField.PROFILE: (PersonProfile, MinistryProfile, ChurchProfile),
    PField.PRIVKEYS: (PrivateKeys, ),
    PField.KEYS: (Keys, ),
    PField.DOMAIN: (Domain, ),
    PField.NODES: (Node, ),
    PField.NODE: (Node, ),
    PField.NET: (Network, ),
    PField.ISSUER_VERIFIED: (Verified, ),
    PField.ISSUER_TRUSTED: (Trusted, ),
    PField.ISSUER_REVOKED: (Revoked, ),
    PField.OWNER_VERIFIED: (Verified, ),
    PField.OWNER_TRUSTED: (Trusted, ),
    PField.OWNER_REVOKED: (Revoked, ),
}

DOCUMENT_PATTERN = {
    DocType.KEYS_PRIVATE: ".pky",
    DocType.KEYS: ".key",
    DocType.ENTITY_PERSON: ".ent",
    DocType.ENTITY_MINISTRY: ".ent",
    DocType.ENTITY_CHURCH: ".ent",
    DocType.PROF_PERSON: ".pfl",
    DocType.PROF_MINISTRY: ".pfl",
    DocType.PROF_CHURCH: ".pfl",
    DocType.NET_DOMAIN: ".dmn",
    DocType.NET_NODE: ".nod",
    DocType.NET_NETWORK: ".net",
    DocType.STAT_VERIFIED: ".ver",
    DocType.STAT_TRUSTED: ".rst",
    DocType.STAT_REVOKED: ".rev",
    DocType.COM_ENVELOPE: ".env",
}

DOCUMENT_TYPE = {
    DocType.KEYS_PRIVATE: PrivateKeys,
    DocType.KEYS: Keys,
    DocType.ENTITY_PERSON: Person,
    DocType.ENTITY_MINISTRY: Ministry,
    DocType.ENTITY_CHURCH: Church,
    DocType.PROF_PERSON: PersonProfile,
    DocType.PROF_MINISTRY: MinistryProfile,
    DocType.PROF_CHURCH: ChurchProfile,
    DocType.NET_DOMAIN: Domain,
    DocType.NET_NODE: Node,
    DocType.NET_NETWORK: Network,
    DocType.STAT_VERIFIED: Verified,
    DocType.STAT_TRUSTED: Trusted,
    DocType.STAT_REVOKED: Revoked,
    DocType.COM_ENVELOPE: Envelope,
    DocType.COM_NOTE: Note,
    DocType.COM_INSTANT: Instant,
    DocType.COM_MAIL: Mail,
    DocType.COM_SHARE: Share,
    DocType.COM_REPORT: Report,
    DocType.CACHED_MSG: StoredLetter,
}

DOCUMENT_PATH = {
    DocType.KEYS_PRIVATE: "{dir}/{file}.pky",
    DocType.KEYS: "{dir}/{file}.key",
    DocType.ENTITY_PERSON: "{dir}/{file}.ent",
    DocType.ENTITY_MINISTRY: "{dir}/{file}.ent",
    DocType.ENTITY_CHURCH: "{dir}/{file}.ent",
    DocType.PROF_PERSON: "{dir}/{file}.pfl",
    DocType.PROF_MINISTRY: "{dir}/{file}.pfl",
    DocType.PROF_CHURCH: "{dir}/{file}.pfl",
    DocType.NET_DOMAIN: "{dir}/{file}.dmn",
    DocType.NET_NODE: "{dir}/{file}.nod",
    DocType.NET_NETWORK: "{dir}/{file}.net",
    DocType.STAT_VERIFIED: "{dir}/{file}.ver",
    DocType.STAT_TRUSTED: "{dir}/{file}.rst",
    DocType.STAT_REVOKED: "{dir}/{file}.rev",
    DocType.COM_ENVELOPE: "{dir}/{file}.env",
    DocType.COM_NOTE: "{dir}/{file}.msg",
    DocType.COM_INSTANT: "{dir}/{file}.msg",
    DocType.COM_MAIL: "{dir}/{file}.msg",
    DocType.COM_SHARE: "{dir}/{file}.msg",
    DocType.COM_REPORT: "{dir}/{file}.msg",
    DocType.CACHED_MSG: "{dir}/{file}.cmsg",
}


class NewPortfolio:

    def __init__(self, docs: set = set()):
        self.__docs = docs
        self.__additional = set()

    def documents(self) -> set:
        """Portfolio original documents."""
        return self.__docs

    def additional(self) -> set:
        """Portfolio added documents."""
        return self.__additional

    def issuer(self):
        """Statements issued by entity."""
        return self._get_issuer(self._get_subset(Document), self.entity.id)

    def owner(self):
        """Statements owned by entity."""
        return self._get_owner(self._get_subset(Document), self.entity.id)

    def _get_type(self, docs: set, doc_cls: type) -> set:
        return {doc for doc in docs if isinstance(doc, doc_cls)}

    def _get_issuer(self, docs: set, issuer: uuid.UUID) -> set:
        return {doc for doc in docs if getattr(doc, "issuer", None) == issuer}

    def _get_owner(self, docs: set, owner: uuid.UUID) -> set:
        return {doc for doc in docs if getattr(doc, "owner", None) == owner}

    def _get_not_expired(self, docs: set) -> set:
        return {doc for doc in docs if not doc.is_expired()}

    def _get_doc(self, types):
        docs = self._get_type(self.__docs | self.__additional, types)
        return docs.pop() if docs else None

    def _get_subset(self, types) -> set:
        docs = self._get_type(self.__docs | self.__additional, types)
        return docs if docs else set()

    def __eq__(self, other):
        s = self.__documents | self.__additional
        o = other.documents | other.__additional
        return collections.Counter(s) == collections.Counter(o)

    def __str__(self):
        issuer = self._get_issuer(self.__docs | self.__additional)
        owner = self._get_owner(self.__docs | self.__additional)
        output = ""

        for doc in issuer:
            output += doc.__class__.__name__ + "\n"
            output += pprint.pformat(doc.export_yaml()) + "\n\n"

        for doc in owner:
            output += doc.__class__.__name__ + "\n"
            output += pprint.pformat(doc.export_yaml()) + "\n\n"

        return output

    def add(self, docs: set):
        """Add documents to the portfolio.

        Documents that are being added will be used for updating the saved portfolio.

        Args:
            docs (set):
                A set of docs to be added.

        """
        self.__additional |= docs

    def complement(self, docs: set):
        """Complement portfolio with updated documents.

        Only use this method when loading complementing updates from the archive.

        Args:
            docs (set):
                A set of docs to be complemented.

        """
        self.__docs |= docs

    @property
    def entity(self):
        """Entity that owns the portfolio."""
        return self._get_doc((Person, Ministry, Church))

    @property
    def profile(self):
        """Profile for the entity."""
        return self._get_doc((PersonProfile, MinistryProfile, ChurchProfile))

    @property
    def keys(self) -> set:
        """Public keys."""
        return self._get_subset(Keys)

    @property
    def network(self):
        """Network for the entity."""
        return self._get_doc(Network)

    @property
    def verified(self) -> set:
        """Verification statements."""
        return self._get_subset(Verified)

    @property
    def trusted(self) -> set:
        """Trust statements."""
        return self._get_subset(Trusted)

    @property
    def revoked(self) -> set:
        """Revokes of statements."""
        return self._get_subset(Revoked)

    @property
    def verified_issuer(self):
        """Verification statements issued by entity."""
        return self._get_issuer(self._get_subset(Verified), self.entity.id)

    @property
    def trusted_issuer(self):
        """Trust statements issued by entity."""
        return self._get_issuer(self._get_subset(Trusted), self.entity.id)

    @property
    def revoked_issuer(self):
        """Revokes of statements issued by entity."""
        return self._get_issuer(self._get_subset(Revoked), self.entity.id)

    @property
    def verified_owner(self):
        """Verification statements owned by entity."""
        return self._get_owner(self._get_subset(Verified), self.entity.id)

    @property
    def trusted_owner(self):
        """Trust statements owned by entity."""
        return self._get_owner(self._get_subset(Trusted), self.entity.id)

    @property
    def revoked_owner(self):
        """Revokes of statements owned by entity."""
        return self._get_owner(self._get_subset(Revoked), self.entity.id)


class NewPrivatePortfolio(NewPortfolio):

    @property
    def privkeys(self):
        """Private keys of entity."""
        return self._get_doc(PrivateKeys)

    @property
    def domain(self):
        """Domain for the entity."""
        return self._get_doc(Domain)

    @property
    def nodes(self) -> set:
        """Nodes of the current domain."""
        return self._get_subset(Node)


# @dataclass
class Statements:
    """
    Statement portfolio

    Portfolio of Statement documents.
    """

    # verified: Set[Verified]
    # trusted: Set[Trusted]
    # revoked: Set[Revoked]

    def __init__(self, *args):
        """Init statement with empty values."""
        self.verified = set()
        self.trusted = set()
        self.revoked = set()

    def to_set(self) -> set:
        return self.verified | self.trusted | self.revoked


# @dataclass
class Portfolio(PortfolioABC):
    """
    Document portfolio.

    A portfolio class holds a set of documents that belongs to an entity. This
    way it is easy to handle documents related to entities and execute policies
    and operations that are related.
    """

    # entity: EntityT
    # profile: ProfileT
    # keys: Set[Keys]
    # network: Network
    # issuer: Statements
    # owner: Statements

    def __init__(self):
        """Init portfolio with empty values."""
        self.entity = None
        self.profile = None
        self.keys = set()
        self.network = None
        self.issuer = Statements()
        self.owner = Statements()

    def __eq__(self, other):
        if callable(getattr(other, "to_sets", None)):
            issuer, owner = self.to_sets()
            s = issuer | owner
            issuer, owner = other.to_sets()
            o = issuer | owner
            return collections.Counter(s) == collections.Counter(o)
        else:
            return False

    def __str__(self):
        issuer, owner = self.to_sets()
        output = ""

        for doc in issuer:
            output += doc.__class__.__name__ + "\n"
            output += pprint.pformat(doc.export_yaml()) + "\n\n"

        for doc in owner:
            output += doc.__class__.__name__ + "\n"
            output += pprint.pformat(doc.export_yaml()) + "\n\n"

        return output

    def _get_type(self, docs: set, doc_cls: type) -> set:
        return {doc for doc in docs if isinstance(doc, doc_cls)}

    def _get_issuer(self, docs: set, issuer: uuid.UUID) -> set:
        return {doc for doc in docs if getattr(doc, "issuer", None) == issuer}

    def _get_owner(self, docs: set, owner: uuid.UUID) -> set:
        return {doc for doc in docs if getattr(doc, "owner", None) == owner}

    def _get_not_expired(self, docs: set) -> set:
        return {doc for doc in docs if not doc.is_expired()}

    def _disassemble(self) -> dict:
        """Disassemble portfolio into dictionary."""
        return {
            PField.ENTITY: self.entity,
            PField.PROFILE: self.profile,
            PField.KEYS: self.keys,
            PField.NET: self.network,
            PField.ISSUER_VERIFIED: self.issuer.verified,
            PField.ISSUER_TRUSTED: self.issuer.trusted,
            PField.ISSUER_REVOKED: self.issuer.revoked,
            PField.OWNER_VERIFIED: self.owner.verified,
            PField.OWNER_TRUSTED: self.owner.trusted,
            PField.OWNER_REVOKED: self.owner.revoked,
        }

    def to_sets(self) -> (Set[DocumentT], Set[DocumentT]):
        """Export documents of portfolio as two sets of docs"""
        issuer = set()
        for attr in ("entity", "profile", "domain", "network", "privkeys"):
            if hasattr(self, attr):
                issuer.add(getattr(self, attr))

        issuer |= (
            self.keys
            | self.issuer.verified
            | self.issuer.trusted
            | self.issuer.revoked
        )
        if hasattr(self, "nodes"):
            issuer |= getattr(self, "nodes")
        owner = self.owner.verified | self.owner.trusted | self.owner.revoked

        try:
            issuer.remove(None)
        except Exception:
            pass

        try:
            owner.remove(None)
        except Exception:
            pass

        return issuer, owner

    def from_sets(
        self, issuer: Set[DocumentT] = set(), owner: Set[DocumentT] = set()
    ) -> bool:
        """
        Import documents to portfolio from two sets of docs.

        Return True if all documents where imported else False.
        """
        all = True
        for doc in issuer:
            if isinstance(doc, (Person, Ministry, Church)):
                setattr(self, "entity", doc)
            elif isinstance(
                doc, (PersonProfile, MinistryProfile, ChurchProfile)
            ):
                setattr(self, "profile", doc)
            elif isinstance(doc, PrivateKeys):
                setattr(self, "privkeys", doc)
            elif isinstance(doc, Domain):
                setattr(self, "domain", doc)
            elif isinstance(doc, Network):
                setattr(self, "network", doc)
            elif isinstance(doc, Keys):
                if hasattr(self, "keys"):
                    self.keys.add(doc)
            elif isinstance(doc, Node):
                if hasattr(self, "nodes"):
                    self.nodes.add(doc)

        for doc in issuer:
            if doc.issuer != self.entity.id:
                continue
            if isinstance(doc, Verified):
                self.issuer.verified.add(doc)
            elif isinstance(doc, Trusted):
                self.issuer.trusted.add(doc)
            elif isinstance(doc, Revoked):
                self.issuer.revoked.add(doc)
            else:
                all = False

        for doc in owner:
            if not hasattr(doc, "owner"):
                continue
            if doc.owner != self.entity.id:
                continue

            if isinstance(doc, Verified):
                self.owner.verified.add(doc)
            elif isinstance(doc, Trusted):
                self.owner.trusted.add(doc)
            elif isinstance(doc, Revoked):
                self.owner.revoked.add(doc)
            else:
                all = False

        return all

    def apply_rules(self):
        return True


# @dataclass
class PrivatePortfolio(Portfolio, PrivatePortfolioABC):
    """Adds private keys to Document portfolio."""

    # privkeys: PrivateKeys
    # domain: Domain
    # nodes: Set[Node]

    def __init__(self):
        """Init private portfolio with empty values."""
        Portfolio.__init__(self)
        self.privkeys = None
        self.domain = None
        self.nodes = set()

    def __eq__(self, other):
        if callable(getattr(other, "to_sets", None)):
            issuer, owner = self.to_sets()
            s = issuer | owner
            issuer, owner = other.to_sets()
            o = issuer | owner
            return collections.Counter(s) == collections.Counter(o)
        else:
            return False

    def to_portfolio(self) -> Portfolio:
        """Get portfolio of private."""
        portfolio = Portfolio()
        issuer, owner = self.to_sets()
        portfolio.from_sets(issuer, owner)
        return portfolio

    def _disassemble(self) -> dict:
        """Disassemble portfolio into dictionary."""
        assembly = super()._disassemble(self)
        assembly[PField.PRIVKEYS] = self.privkeys
        assembly[PField.DOMAIN] = self.domain
        assembly[PField.NODES] = self.nodes
        return assembly

    @classmethod
    def factory(cls, issuer: set, owner: set) -> "PrivatePortfolio":
        portfolio = cls()
        portfolio.from_sets(issuer, owner)
        return portfolio

    def apply_rules(self):
        return True


class PortfolioPolicy:
    """Portfolio load configurations."""

    @staticmethod
    def serialize(document: DocumentT) -> bytes:
        """"Serialize document into streams of bytes."""
        return msgpack.packb(
            document.export_bytes(), use_bin_type=True, strict_types=True
        )

    @staticmethod
    def deserialize(data: bytes) -> DocumentT:
        """Restore document from stream of bytes."""
        docobj = msgpack.unpackb(data, raw=False)
        return DOCUMENT_TYPE[
            int.from_bytes(docobj["type"], byteorder="big")
        ].build(docobj)

    @staticmethod
    def exports(portfolio: Portfolio) -> bytes:
        """Export portfolio of documents to bytes."""
        issuer, owner = portfolio.to_sets()
        docs = []
        for doc in issuer | owner:
            docs.append(doc.export_bytes())

        return msgpack.packb(docs, use_bin_type=True, strict_types=True)

    @staticmethod
    def imports(data: bytes) -> Portfolio:
        """Import portfolio of documents from bytes."""
        docobjs = msgpack.unpackb(data, raw=False)
        docs = set()
        for obj in docobjs:
            docs.add(
                DOCUMENT_TYPE[
                    int.from_bytes(obj["type"], byteorder="big")
                ].build(obj)
            )

        portfolio = Portfolio()
        portfolio.from_sets(docs, docs)
        return portfolio

    @staticmethod
    def validate(portfolio: Portfolio, config: Tuple[str]) -> bool:
        """Validate each document from the portfolio in the documents list."""
        for doc in config:
            if isinstance(doc, Iterable):
                for item in doc:
                    item.validate()
            else:
                doc.validate()

        return True

    @staticmethod
    def validate_belonging(portfolio: Portfolio) -> bool:
        """Validates that all elements belong to entity."""
        raise NotImplementedError()

    @staticmethod
    def validate_verify(portfolio: Portfolio) -> bool:
        """
        Verify cryptographically the documents.

        Validate issuership of all except "owner" docs.
        """
        raise NotImplementedError()

    @staticmethod
    def doc2fileident(document: DocumentT) -> str:
        """Translate document into file identifier."""
        if document.type in (
            DocType.COM_ENVELOPE,
            DocType.COM_NOTE,
            DocType.COM_INSTANT,
            DocType.COM_MAIL,
            DocType.COM_SHARE,
            DocType.COM_REPORT,
        ):
            return ""
        else:
            return "{0}{1}".format(
                document.id, DOCUMENT_PATTERN[document.type]
            )

    @staticmethod
    def path2fileident(filename: str) -> str:
        """Translate document into file identifier."""
        return filename[-40:]

    @staticmethod
    def factory(assembly: dict) -> Portfolio:
        """Assemble a portfolio from dictionary."""
        fields = assembly.keys()

        if PField.PRIVKEYS in fields:
            portfolio = PrivatePortfolio()
        else:
            portfolio = Portfolio()

        if PField.ENTITY in fields:
            portfolio.entity = assembly[PField.ENTITY]

        if PField.PROFILE in fields:
            portfolio.profile = assembly[PField.PROFILE]

        if PField.PRIVKEYS in fields:
            portfolio.privkeys = assembly[PField.PRIVKEYS]

        if PField.DOMAIN in fields:
            portfolio.domain = assembly[PField.DOMAIN]

        if PField.NET in fields:
            portfolio.network = assembly[PField.NET]

        if PField.KEYS in fields:
            portfolio.keys = assembly[PField.KEYS]

        if PField.NODES in fields:
            portfolio.nodes = assembly[PField.NODES]

        if PField.ISSUER_VERIFIED in fields:
            portfolio.issuer.verified = assembly[PField.ISSUER_VERIFIED]

        if PField.ISSUER_TRUSTED in fields:
            portfolio.issuer.trusted = assembly[PField.ISSUER_TRUSTED]

        if PField.ISSUER_REVOKED in fields:
            portfolio.issuer.revoked = assembly[PField.ISSUER_REVOKED]

        if PField.OWNER_VERIFIED in fields:
            portfolio.owner.verified = assembly[PField.OWNER_VERIFIED]

        if PField.OWNER_TRUSTED in fields:
            portfolio.owner.trusted = assembly[PField.OWNER_TRUSTED]

        if PField.OWNER_REVOKED in fields:
            portfolio.owner.revoked = assembly[PField.OWNER_REVOKED]

        return portfolio

    @staticmethod
    def is_importable(portfolio: Portfolio, field: str, doc: DocumentT):
        """Test if a document is importable.

        In order to be importable the document has to be non-existent in the portfolio.

        Args:
            portfolio:
            field:
            doc:

        Returns:

        """
        if isinstance(doc, type(None)):
            return False
        content = getattr(portfolio, field, -1)
        if content is -1:
            raise AttributeError("Field doesn't exist.")
        if not isinstance(doc, PORTFOLIO_TYPE[field]):
            raise TypeError("Wrong document type for this field")

        if isinstance(content, type(None)):
            # If the content is None it means that the single field is empty and free to populate
            return True
        elif not isinstance(content, set):
            # If the content is not a set it means that the single field is a document
            content = set([content])

        # In order to be importable the candidate document can not already exist.
        return len({document for document in content if document.compare(doc)}) == 0

    @staticmethod
    def is_updatable(portfolio: Portfolio, field: str, doc: DocumentT):
        """Test if a document is updatable.

        In order to be importable the document has to be existent in the portfolio but newer.

        Args:
            portfolio:
            field:
            doc:

        Returns:

        """
        if isinstance(doc, type(None)):
            return False
        content = getattr(portfolio, field, -1)
        if content is -1:
            raise AttributeError("Field doesn't exist.")
        if not isinstance(doc, PORTFOLIO_TYPE[field]):
            raise TypeError("Wrong document type for this field")

        if isinstance(content, type(None)):
            # If content is None it means it is importable and not updatable.
            return False
        elif not isinstance(content, set):
            # If the content is not a set it means that the single field is a document
            content = set([content])

        # In order to be updatable the candidate document must already exist and be newer.
        return len({document for document in content if document.compare(doc) and document < doc}) > 0


class DocSet:
    """Class for sets of documents"""

    def __init__(self, documents: Set[DocumentT]):
        """Init docset with a set of docs."""
        self._docs = documents

    def __len__(self) -> int:
        """The length of the set."""
        return len(self._docs)

    def issuers(self) -> Set[uuid.UUID]:
        """Unique set of all the issuers."""
        return {doc.issuer for doc in self._docs}

    def get_issuer(self, issuer: uuid.UUID) -> Set[DocumentT]:
        """Get all documents of issuer and subtract from set."""
        get = {doc for doc in self._docs if doc.issuer.int == issuer.int}
        self._docs -= get
        return get

    def get_owner(self, owner: uuid.UUID) -> Set[DocumentT]:
        """Get all documents of owner and subtract from set."""
        get = {doc for doc in self._docs if doc.owner.int == owner.int}
        self._docs -= get
        return get