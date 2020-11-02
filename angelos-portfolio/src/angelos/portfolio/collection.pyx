# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
import collections
import pprint
import uuid
from typing import Union, Tuple, Iterator, Set

from angelos.common.policy import PolicyException, policy
from angelos.document.document import Document
from angelos.document.domain import Network, Domain, Node
from angelos.document.entities import Person, Ministry, Church, Keys, PrivateKeys
from angelos.document.entity_mixin import PersonMixin, MinistryMixin, ChurchMixin
from angelos.document.model import DocumentMeta
from angelos.document.profiles import PersonProfile, MinistryProfile, ChurchProfile, Profile
from angelos.document.statements import Verified, Trusted, Revoked


class FrozenPortfolioError(RuntimeWarning):
    """Complaining on frozen portfolio when it must be mutable."""
    pass


class WrongPortfolioIdentity(RuntimeWarning):
    """Complaining of wrong portfolio identity assigned."""
    pass


class Portfolio(collections.abc.Collection):
    """Collection of public documents belonging and related to an entity."""

    def __init__(self, docs: Set[Document], frozen: bool = True):
        self.__docs = docs
        self.__frozen = frozen

    def documents(self) -> Set[Document]:
        """Portfolio original documents."""
        return set(self.__docs) if self.__frozen else self.__docs

    def freeze(self):
        """Freeze the portfolio so it can't be tampered with"""
        self.__frozen = True

    def is_frozen(self) -> bool:
        """True if portfolio is frozen, else false."""
        return self.__frozen

    def issuer(self) -> Set[Document]:
        """Statements issued by entity."""
        return self.get_issuer(self.get_subset(Document), self.entity.id)

    def owner(self) -> Set[Document]:
        """Statements owned by entity."""
        return self.get_owner(self.get_subset(Document), self.entity.id)

    def filter(self, docs: Set[Document]) -> Set[Document]:
        """Filter out the current portfolio documents against given set."""
        ids = {doc.id for doc in docs}
        return {doc for doc in self.__docs if doc.id not in ids}

    def get_type(self, docs: set, doc_cls: Union[DocumentMeta, Tuple[DocumentMeta, ...]]) -> Set[Document]:
        """Get set of documents filtered by class."""
        return {doc for doc in docs if isinstance(doc, doc_cls)}

    def get_issuer(self, docs: Set[Document], issuer: uuid.UUID) -> Set[Document]:
        """Get set of documents based on issuer."""
        return {doc for doc in docs if getattr(doc, "issuer", None) == issuer}

    def get_owner(self, docs: Set[Document], owner: uuid.UUID) -> Set[Document]:
        """Get set of documents based on owner."""
        return {doc for doc in docs if getattr(doc, "owner", None) == owner}

    def get_id(self, doc_id: uuid.UUID) -> Document:
        """Get document based on id."""
        docs = {doc for doc in self.__docs if doc.id == doc_id}
        return docs.pop() if docs else None

    def get_not_expired(self, docs: Set[Document]) -> Set[Document]:
        """Get set of documents based on expiry date."""
        return {doc for doc in docs if not doc.is_expired()}

    def get_doc(self, types) -> Document:
        """Get first document from set of document class."""
        docs = self.get_type(self.__docs, types)
        return docs.pop() if docs else None

    def get_subset(self, types: Union[DocumentMeta, Tuple[DocumentMeta, ...]]) -> Set[Document]:
        """Get a subset of classes based on document class."""
        docs = self.get_type(self.__docs, types)
        return docs if docs else set()

    def __len__(self) -> int:
        return len(self.__docs)

    def __iter__(self) -> Iterator[Document]:
        for doc in self.__docs:
            yield doc

    def __contains__(self, document: Document) -> bool:
        for doc in self.__docs:
            if doc.id == document.id:
                return True
        return False

    def __eq__(self, other: "Portfolio") -> bool:
        return collections.Counter(self.__docs) == collections.Counter(other.documents())

    def __str__(self) -> str:
        output = ""

        for doc in self.__docs:
            output += doc.__class__.__name__ + "\n"
            output += pprint.pformat(doc.export_yaml()) + "\n\n"

        return output

    @property
    def entity(self) -> Union[Person, Ministry, Church]:
        """Entity that owns the portfolio."""
        return self.get_doc((Person, Ministry, Church))

    @property
    def profile(self) -> Union[PersonProfile, MinistryProfile, ChurchProfile]:
        """Profile for the entity."""
        return self.get_doc((PersonProfile, MinistryProfile, ChurchProfile))

    @property
    def keys(self) -> Set[Keys]:
        """Public keys."""
        return self.get_subset(Keys)

    @property
    def network(self) -> Network:
        """Network for the entity."""
        return self.get_doc(Network)

    @property
    def statements(self) -> Set[Union[Verified, Trusted, Revoked]]:
        """Statements."""
        return self.get_subset((Verified, Trusted, Revoked))

    @property
    def verified(self) -> Set[Verified]:
        """Verification statements."""
        return self.get_subset(Verified)

    @property
    def trusted(self) -> Set[Trusted]:
        """Trust statements."""
        return self.get_subset(Trusted)

    @property
    def revoked(self) -> Set[Revoked]:
        """Revokes of statements."""
        return self.get_subset(Revoked)

    @property
    def verified_issuer(self) -> Set[Verified]:
        """Verification statements issued by entity."""
        return self.get_issuer(self.get_subset(Verified), self.entity.id)

    @property
    def trusted_issuer(self) -> Set[Trusted]:
        """Trust statements issued by entity."""
        return self.get_issuer(self.get_subset(Trusted), self.entity.id)

    @property
    def revoked_issuer(self) -> Set[Revoked]:
        """Revokes of statements issued by entity."""
        return self.get_issuer(self.get_subset(Revoked), self.entity.id)

    @property
    def verified_owner(self) -> Set[Verified]:
        """Verification statements owned by entity."""
        return self.get_owner(self.get_subset(Verified), self.entity.id)

    @property
    def trusted_owner(self) -> Set[Trusted]:
        """Trust statements owned by entity."""
        return self.get_owner(self.get_subset(Trusted), self.entity.id)

    @property
    def revoked_owner(self) -> Set[Revoked]:
        """Revokes of statements owned by entity."""
        return self.get_owner(self.get_subset(Revoked), self.entity.id)


class PrivatePortfolio(Portfolio):
    """Private documents of an entity."""

    @property
    def privkeys(self) -> PrivateKeys:
        """Private keys of entity."""
        return self.get_doc(PrivateKeys)

    @property
    def domain(self) -> Domain:
        """Domain for the entity."""
        return self.get_doc(Domain)

    @property
    def nodes(self) -> Set[Node]:
        """Nodes of the current domain."""
        return self.get_subset(Node)


class Operations:
    """Operations carried out on a portfolio, policies applied."""

    @staticmethod
    @policy(b"I", 0)
    def _check_entity_present(p: Portfolio) -> bool:
        """Portfolio must have entity document."""
        if not p.entity:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_entity_many(p: Portfolio) -> bool:
        """Portfolio must not have several entity documents."""
        if len(p.get_subset((Person, Ministry, Church))) > 1:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_entity_expired(p: Portfolio) -> bool:
        """Entity document must not be expired."""
        if p.entity.is_expired():
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_keys_present(p: Portfolio) -> bool:
        """Portfolio must have, and may have several keys documents."""
        if not len(p.keys) >= 1:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_keys_expired(p: Portfolio) -> bool:
        """At least one keys must not be expired."""
        if not any([not k.is_expired() for k in p.keys]):
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_keys_old(p: Portfolio) -> bool:
        """Keys must not be older than three years."""
        if not any([k.is_way_old() for k in p.keys]):
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_network_many(p: Portfolio) -> bool:
        """Portfolio may have, but must not have several network documents."""
        if len(p.get_subset(Network)) > 1:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_network_expired(p: Portfolio) -> bool:
        """Network document must not be expired."""
        if p.network:
            if p.network.is_expired():
                raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_profile_many(p: Portfolio) -> bool:
        """Portfolio may have, but must not have several profile documents."""
        if len(p.get_subset(Profile)) > 1:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_profile_expired(p: Portfolio) -> bool:
        """Profile document must not be expired."""
        if p.profile:
            if p.profile.is_expired():
                raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_profile_correlation(p: Portfolio) -> bool:
        """profile document must match entity document by designated type."""
        if p.profile:
            if not p.entity:
                raise PolicyException()
            if not any(isinstance(p.profile, i) and isinstance(p.entity, i) for i in (
                    PersonMixin, MinistryMixin, ChurchMixin)):
                raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_statement_old(p: Portfolio) -> bool:
        """Keys must not be older than three years."""
        if any([s.is_way_old() for s in p.statements]):
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_statement_owner(p: Portfolio) -> bool:
        """Portfolio entity must be owner or issuer of statements."""
        if not p.entity:
            raise PolicyException()
        if any([s.get_owner() != p.entity.id for s in p.statements]):
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_privkeys_present(p: Portfolio) -> bool:
        """Portfolio must have private keys document."""
        if not p.privkeys:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_privkeys_many(p: Portfolio) -> bool:
        """Portfolio must not have several private keys documents."""
        if len(p.get_subset(PrivateKeys)) > 1:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_privkeys_expired(p: Portfolio) -> bool:
        """Private key document must not be expired."""
        if p.privkeys.is_expired():
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_domain_present(p: Portfolio) -> bool:
        """Portfolio must have domain document."""
        if not p.domain:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_domain_many(p: Portfolio) -> bool:
        """Portfolio must not have several domain documents."""
        if len(p.get_subset(Domain)) > 1:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_domain_expired(p: Portfolio) -> bool:
        """Domain document must not be expired."""
        if p.domain.is_expired():
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_nodes_present(p: Portfolio) -> bool:
        """Portfolio must have nodes document."""
        if not len(p.nodes) >= 1:
            raise PolicyException()
        return True

    @staticmethod
    @policy(b"I", 0)
    def _check_nodes_expired(p: Portfolio) -> bool:
        """Not one nodes document may have expired."""
        if any([n.is_expired() for n in p.nodes]):
            raise PolicyException()
        return True

    @policy(b"I", 0)
    def _check_portfolio_overflow(portfolio: Portfolio) -> bool:
        """Check that there are no illicit documents in portfolio."""
        docs = {portfolio.entity, portfolio.profile, portfolio.network} | portfolio.keys \
               | portfolio.verified_issuer | portfolio.trusted_issuer | portfolio.revoked_issuer \
               | portfolio.verified_owner | portfolio.trusted_owner | portfolio.revoked_owner
        if isinstance(portfolio, PrivatePortfolio):
            docs |= {portfolio.privkeys, portfolio.domain} | portfolio.nodes
        if collections.Counter(docs) != collections.Counter(portfolio.documents()):
            raise PolicyException()
        return True

    @policy(b"I", 0)
    def _check_portfolio_issued(portfolio: Portfolio) -> bool:
        """Check that there are only issued documents in portfolio."""
        if collections.Counter(portfolio.issuer()) != collections.Counter(portfolio.documents()):
            raise PolicyException()
        return True

    @policy(b"I", 0)
    def _check_portfolio_owned(portfolio: Portfolio) -> bool:
        """Check that there are only owned and issued documents in portfolio."""
        if collections.Counter(portfolio.issuer() | portfolio.owned()) != collections.Counter(portfolio.documents()):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_same_fieldnames(self) -> bool:
        if not self._entity.fields() == self._portfolio.entity.fields():
            raise PolicyException()
        return True

    @policy(b"I", 0)
    def validate(self, portfolio: Portfolio):
        """Validate all the documents in the portfolio."""

        check = [
            # portfolio.entity
            Operations._check_entity_present(portfolio),
            Operations._check_entity_many(portfolio),
            Operations._check_entity_expired(portfolio),
            # portfolio.keys
            Operations._check_keys_present(portfolio),
            Operations._check_keys_expired(portfolio),
            Operations._check_keys_old(portfolio),
            # portfolio.network
            Operations._check_network_many(portfolio),
            Operations._check_network_expired(portfolio),
            # portfolio.profile
            Operations._check_profile_many(portfolio),
            Operations._check_profile_expired(portfolio),
            Operations._check_profile_correlation(portfolio),
            # portfolio.statements
            Operations._check_statement_owner(portfolio),
            Operations._check_statement_old(portfolio),
        ]

        if isinstance(portfolio, PrivatePortfolio):
            check += [
                # portfolio.privkeys
                Operations._check_privkeys_present(),
                Operations._check_privkeys_many(),
                Operations._check_privkeys_expired(),
                # portfolio.domain
                Operations._check_domain_present(),
                Operations._check_domain_many(),
                Operations._check_domain_expired(),
                # portfolio.nodes
                Operations._check_nodes_present(),
                Operations._check_nodes_expired(),
            ]

        if not all(check):
            raise PolicyException()
