# cython: language_level=3
"""Policy classes for document portfolios."""
import enum

from dataclasses import dataclass
from typing import List, Set

from ._types import (
    PersonData, MinistryData, ChurchData, PortfolioABC, PrivatePortfolioABC)
from .entity import PersonPolicy, MinistryPolicy, ChurchPolicy
from ..document import (
    Entity, Profile, PrivateKeys, Keys, Domain, Node, Network, Verified,
    Trusted, Revoked)


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
    __slots__ = ('verified', 'trusted', 'revoked')
    verified: Set[Verified]
    trusted: Set[Trusted]
    revoked: Set[Revoked]


@dataclass
class Portfolio(PortfolioABC):
    """
    Document portfolio.

    A portfolio class holds a set of documents that belongs to an entity. This
    way it is easy to handle documents related to entities and execute policies
    and operations that are related.
    """
    __slots__ = (
        'entity', 'profile', 'keys', 'domain', 'nodes', 'network', 'issuer',
        'owner')

    entity: Entity
    profile: Profile
    keys: List[Keys]
    domain: Domain
    nodes: Set[Node]
    network: Network
    issuer: Statements
    owner: Statements


@dataclass
class PrivatePortfolio(Portfolio, PrivatePortfolioABC):
    """Adds private keys to Document portfolio."""
    # __slots__ = ('privkeys')

    privkeys: PrivateKeys = None

    def from_person_data(data: PersonData) -> Portfolio:
        return PrivatePortfolio(PersonPolicy.generate(data))

    def from_ministry_data(data: MinistryData) -> Portfolio:
        return PrivatePortfolio(MinistryPolicy.generate(data))

    def from_church_data(data: ChurchData) -> Portfolio:
        return PrivatePortfolio(ChurchPolicy.generate(data))
