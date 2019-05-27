# cython: language_level=3
"""Policy classes for document portfolios."""
import enum

from dataclasses import dataclass
from typing import List, Set, Tuple
from collections.abc import Iterable

from ._types import PortfolioABC, PrivatePortfolioABC
from ..document import (
    Document, Entity, Profile, PrivateKeys, Keys, Domain, Node, Network,
    Statement, Verified, Trusted, Revoked)


class PField(enum.Enum):
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


class PGroup(enum.Enum):
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
    def validate(portfolio: Portfolio, documents: Tuple[str]) -> bool:
        """Validate each document from the portfolio in the documents list."""
        for doc in documents:
            if isinstance(doc, Iterable):
                for item in doc:
                    item.validate()
            else:
                doc.validate()

        return True

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
