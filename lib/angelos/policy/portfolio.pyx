# cython: language_level=3
"""Policy classes for document portfolios."""
from dataclasses import dataclass
from typing import List, Set, Tuple
from collections.abc import Iterable

import msgpack

from ._types import PortfolioABC, PrivatePortfolioABC
from ..document import (
    DocType, Document, Entity, Profile, PrivateKeys, Keys, Domain, Node,
    Network, Statement, Verified, Trusted, Revoked, Person, Ministry, Church,
    PersonProfile, MinistryProfile, ChurchProfile, Envelope, Note, Instant,
    Mail, Share, Report)


class PField:
    ENTITY = 'entity'
    PROFILE = 'profile'
    PRIVKEYS = 'privkeys'
    KEYS = 'keys'
    DOMAIN = 'domain'
    NODE = 'node'
    NODES = 'nodes'
    NET = 'network'

    ISSUER_VERIFIED = 'issuer.verified'
    ISSUER_TRUSTED = 'issuer.trusted'
    ISSUER_REVOKED = 'issuer.revoked'

    OWNER_VERIFIED = 'owner.verified'
    OWNER_TRUSTED = 'owner.trusted'
    OWNER_REVOKED = 'owner.revoked'


class PGroup:
    """Definitions of different sets of documents for different purposes."""

    # Basic set for verifying documents
    VERIFIER = (PField.ENTITY, PField.KEYS)
    # Basic set for signing documents
    SIGNER = (PField.ENTITY, PField.PRIVKEYS, PField.KEYS)
    # Basic set for running Client Facade
    CLIENT = (
        PField.ENTITY, PField.PRIVKEYS, PField.KEYS, PField.DOMAIN,
        PField.NODES)
    # Basic set for running Server Facade
    SERVER = (
        PField.ENTITY, PField.PRIVKEYS, PField.KEYS, PField.DOMAIN,
        PField.NODES, PField.NET)
    # Documents issued by issuer
    ISSUER = (
        PField.ISSUER_VERIFIED, PField.ISSUER_TRUSTED, PField.ISSUER_REVOKED)
    # Documents issued by others
    OWNER = (
        PField.OWNER_VERIFIED, PField.OWNER_TRUSTED, PField.OWNER_REVOKED)
    # Minimum set for sharing identity
    SHARE_MIN_USER = (PField.ENTITY, PField.KEYS)
    # Minimum set for sharing community
    SHARE_MIN_COMMUNITY = (PField.ENTITY, PField.KEYS, PField.NET)
    # Medium set for sharing identity
    SHARE_MED_USER = (PField.ENTITY, PField.PROFILE, PField.KEYS)
    # Medium set for sharing community
    SHARE_MED_COMMUNITY = (
        PField.ENTITY, PField.PROFILE, PField.KEYS, PField.NET)
    # Maximum set for sharing identity
    SHARE_MAX_USER = (
        PField.ENTITY, PField.PROFILE, PField.KEYS, PField.OWNER_VERIFIED,
        PField.OWNER_TRUSTED)
    # Maximum set for sharing community
    SHARE_MAX_COMMUNITY = (
        PField.ENTITY, PField.PROFILE, PField.KEYS, PField.NET,
        PField.OWNER_VERIFIED, PField.OWNER_TRUSTED)
    # Complete set of documents of all types
    ALL = (
        PField.ENTITY, PField.PROFILE, PField.PROFILE, PField.KEYS,
        PField.DOMAIN, PField.NODE, PField.NODES, PField.NET,
        PField.ISSUER_VERIFIED, PField.ISSUER_TRUSTED, PField.ISSUER_REVOKED,
        PField.OWNER_VERIFIED, PField.OWNER_TRUSTED, PField.OWNER_REVOKED)


PORTFOLIO_TEMPLATE = {
    PField.ENTITY: '{dir}/{file}.ent',
    PField.PROFILE: '{dir}/{file}.pfl',
    PField.PRIVKEYS: '{dir}/{file}.pky',
    PField.KEYS: '{dir}/{file}.key',
    PField.DOMAIN: '{dir}/{file}.dmn',
    PField.NODES: '{dir}/{file}.nod',
    PField.NET: '{dir}/{file}.net',
    PField.ISSUER_VERIFIED: '{dir}/{file}.ver',
    PField.ISSUER_TRUSTED: '{dir}/{file}.rst',
    PField.ISSUER_REVOKED: '{dir}/{file}.rev',
    PField.OWNER_VERIFIED: '{dir}/{file}.ver',
    PField.OWNER_TRUSTED: '{dir}/{file}.rst',
    PField.OWNER_REVOKED: '{dir}/{file}.rev'
}

PORTFOLIO_PATTERN = {
    PField.ENTITY: '.ent',
    PField.PROFILE: 'pfl',
    PField.PRIVKEYS: '.pky',
    PField.KEYS: '.key',
    PField.DOMAIN: '.dmn',
    PField.NODES: '.nod',
    PField.NET: '.net',
    PField.ISSUER_VERIFIED: '.ver',
    PField.ISSUER_TRUSTED: '.rst',
    PField.ISSUER_REVOKED: '.rev',
    PField.OWNER_VERIFIED: '.ver',
    PField.OWNER_TRUSTED: '.rst',
    PField.OWNER_REVOKED: '.rev'
}

DOCUMENT_PATTERN = {
    DocType.KEYS_PRIVATE: '.pky',
    DocType.KEYS: '.key',
    DocType.ENTITY_PERSON: '.ent',
    DocType.ENTITY_MINISTRY: '.ent',
    DocType.ENTITY_CHURCH: '.ent',
    DocType.PROF_PERSON: '.pfl',
    DocType.PROF_MINISTRY: '.pfl',
    DocType.PROF_CHURCH: '.pfl',
    DocType.NET_DOMAIN: '.dmn',
    DocType.NET_NODE: '.nod',
    DocType.NET_NETWORK: '.net',
    DocType.STAT_VERIFIED: '.ver',
    DocType.STAT_TRUSTED: '.rst',
    DocType.STAT_REVOKED: '.rev',
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
}

DOCUMENT_PATH = {
    DocType.KEYS_PRIVATE: '{dir}/{file}.pky',
    DocType.KEYS: '{dir}/{file}.key',
    DocType.ENTITY_PERSON: '{dir}/{file}.ent',
    DocType.ENTITY_MINISTRY: '{dir}/{file}.ent',
    DocType.ENTITY_CHURCH: '{dir}/{file}.ent',
    DocType.PROF_PERSON: '{dir}/{file}.pfl',
    DocType.PROF_MINISTRY: '{dir}/{file}.pfl',
    DocType.PROF_CHURCH: '{dir}/{file}.pfl',
    DocType.NET_DOMAIN: '{dir}/{file}.dmn',
    DocType.NET_NODE: '{dir}/{file}.nod',
    DocType.NET_NETWORK: '{dir}/{file}.net',
    DocType.STAT_VERIFIED: '{dir}/{file}.ver',
    DocType.STAT_TRUSTED: '{dir}/{file}.rst',
    DocType.STAT_REVOKED: '{dir}/{file}.rev',
}


@dataclass
class Statements:
    """
    Statement portfolio

    Portfolio of Statement documents.
    """
    __slots__ = ('_save', 'verified', 'trusted', 'revoked')

    _save: Set[Statement]
    verified: Set[Verified]
    trusted: Set[Trusted]
    revoked: Set[Revoked]

    def __init__(self, *args):
        """Init statement with empty values."""
        self._save = set()
        self.verified = set()
        self.trusted = set()
        self.revoked = set()

    def reset(self):
        """Reset save value."""
        self._save = set()


@dataclass
class Portfolio(PortfolioABC):
    """
    Document portfolio.

    A portfolio class holds a set of documents that belongs to an entity. This
    way it is easy to handle documents related to entities and execute policies
    and operations that are related.
    """
    __slots__ = (
        '_save', 'entity', 'profile', 'keys', 'domain', 'nodes', 'network',
        'issuer', 'owner')

    _save: Set[Document]
    entity: Entity
    profile: Profile
    keys: List[Keys]
    domain: Domain
    nodes: Set[Node]
    network: Network
    issuer: Statements
    owner: Statements

    def __init__(self):
        """Init portfolio with empty values."""
        self._save = set()
        self.entity = None
        self.profile = None
        self.keys = []
        self.domain = None
        self.nodes = set()
        self.network = None
        self.issuer = Statements()
        self.owner = Statements()

    def reset(self):
        """Reset save flag."""
        self._save = set()

    def _disassemble(self) -> dict:
        """Disassemble portfolio into dictionary."""
        return {
            PField.ENTITY: self.entity,
            PField.PROFILE: self.profile,
            PField.KEYS: self.keys,
            PField.DOMAIN: self.domain,
            PField.NODES: self.nodes,
            PField.NET: self.network,
            PField.ISSUER_VERIFIED: self.issuer.verified,
            PField.ISSUER_TRUSTED: self.issuer.trusted,
            PField.ISSUER_REVOKED: self.issuer.revoked,
            PField.OWNER_VERIFIED: self.owner.verified,
            PField.OWNER_TRUSTED: self.owner.trusted,
            PField.OWNER_REVOKED: self.owner.revoked
        }

    def to_sets(self):  # -> Set[Document], Set[Document]:
        """Export documents of portfolio as two sets of docs"""
        issuer = (
            set([self.entity, self.profile, self.domain,
                 self.network, self.privkeys]) |
            set(self.keys) | self.nodes | self.issuer.verified |
            self.issuer.trusted | self.issuer.revoked)
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

    def from_sets(self,
                  issuer: Set[Document]=set(),
                  owner: Set[Document]=set()) -> bool:
        """
        Import documents to portfolio from two sets of docs.

        Return True if all documents where imported else False.
        """
        all = True
        for doc in issuer:
            if isinstance(doc, (Person, Ministry, Church)):
                self.entity = doc
            elif isinstance(doc, (
                    PersonProfile, MinistryProfile, ChurchProfile)):
                self.profile = doc
            elif isinstance(doc, PrivateKeys):
                self.privkeys = doc
            elif isinstance(doc, Domain):
                self.domain = doc
            elif isinstance(doc, Network):
                self.network = doc
            elif isinstance(doc, Keys):
                self.keys.append(doc)
            elif isinstance(doc, Node):
                self.nodes.add(doc)
            elif isinstance(doc, Verified):
                self.issuer.verified.add(doc)
            elif isinstance(doc, Trusted):
                self.issuer.trusted.add(doc)
            elif isinstance(doc, Revoked):
                self.issuer.revoked.add(doc)
            else:
                all = False

        for doc in owner:
            if isinstance(doc, Verified):
                self.owner.verified.add(doc)
            elif isinstance(doc, Trusted):
                self.owner.trusted.add(doc)
            elif isinstance(doc, Revoked):
                self.owner.revoked.add(doc)
            else:
                all = False

        return all


@dataclass
class PrivatePortfolio(Portfolio, PrivatePortfolioABC):
    """Adds private keys to Document portfolio."""

    privkeys: PrivateKeys

    def __init__(self):
        """Init private portfolio with empty values."""
        Portfolio.__init__(self)
        self.privkeys = None

    def to_portfolio(self) -> Portfolio:
        """Get portfolio of private."""
        return self.super()

    def _disassemble(self) -> dict:
        """Disassemble portfolio into dictionary."""
        assembly = self.super()._disassemble()
        assembly[PField.PRIVKEYS] = self.privkeys
        return assembly


class PortfolioPolicy:
    """Portfolio load configurations."""

    @staticmethod
    def serialize(document: Document) -> bytes:
        """"Serialize document into streams of bytes."""
        return msgpack.packb(
            document.export_bytes(), use_bin_type=True, strict_types=True)

    @staticmethod
    def deserialize(data: bytes) -> Document:
        """Restore document from stream of bytes."""
        docobj = msgpack.unpackb(data, raw=False)
        return DOCUMENT_TYPE[int.from_bytes(
            docobj['type'], byteorder='big')].build(docobj)

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
        """Valdidates that all elements belong to entity."""
        raise NotImplementedError()

    @staticmethod
    def validate_verify(portfolio: Portfolio) -> bool:
        """
        Verify cryptographicaly the documents.

        Validate issuership of all except "owner" docs.
        """
        raise NotImplementedError()

    @staticmethod
    def doc2fileident(document: Document) -> str:
        """Translate document into file identifier."""
        if document.type in (
                DocType.COM_ENVELOPE, DocType.COM_NOTE, DocType.COM_INSTANT,
                DocType.COM_MAIL, DocType.COM_SHARE, DocType.COM_REPORT):
            return ''
        else:
            return '{0}{1}'.format(
                document.id, DOCUMENT_PATTERN[document.type])

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
