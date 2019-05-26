# cython: language_level=3
"""Policy classes for document portfolios."""
import enum

from dataclasses import dataclass
from typing import List, Set

from ._types import PortfolioABC, PrivatePortfolioABC
from ..document import (
    Document, Entity, Profile, PrivateKeys, Keys, Domain, Node, Network,
    Statement, Verified, Trusted, Revoked)


class PortfolioLoader(enum.Enum):
    """Portfolio load configurations."""
    ALL = (
        'entity', 'profile', 'privkeys', 'keys', 'domain', 'node', 'nodes',
        'network', 'issuer.verified', 'issuer.trusted', 'issuer.revoked',
        'owner.verified', 'owner.trusted', 'owner.revoked')

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

    ISSUER = ('issuer.verified', 'issuer.trusted', 'issuer.revoked')
    OWNER = ('owner.verified', 'owner.trusted', 'owner.revoked')

    VERIFIER = ('entity', 'keys')
    SIGNER = ('entity', 'privkeys', 'keys')
    CLIENT = ('entity', 'privkeys', 'keys', 'domain', 'nodes')
    SERVER = ('entity', 'privkeys', 'keys', 'domain', 'nodes', 'network')
    SHARE_MIN_USER = ('entity', 'keys')
    SHARE_MIN_COMMUNITY = ('entity', 'keys', 'network')
    SHARE_MED_USER = ('entity', 'profile', 'keys')
    SHARE_MED_COMMUNITY = ('entity', 'profile', 'keys', 'network')
    SHARE_MAX_USER = (
        'entity', 'profile', 'keys', 'owner.verified', 'owner.trusted')
    SHARE_MAX_COMMUNITY = (
        'entity', 'profile', 'keys', 'network', 'owner.verified',
        'owner.trusted')


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
        self._save = set()
        self.verified = set()
        self.trusted = set()
        self.revoked = set()

    def reset(self):
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
        self._save = set()


@dataclass
class PrivatePortfolio(Portfolio, PrivatePortfolioABC):
    """Adds private keys to Document portfolio."""

    privkeys: PrivateKeys

    def __init__(self):
        Portfolio.__init__(self)
        self.privkeys = None

    def to_portfolio(self) -> Portfolio:
        return self.super()
