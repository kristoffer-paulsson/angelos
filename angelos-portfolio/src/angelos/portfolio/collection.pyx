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

from angelos.document.document import Document
from angelos.document.domain import Network, Domain, Node
from angelos.document.entities import Person, Ministry, Church, Keys, PrivateKeys
from angelos.document.profiles import PersonProfile, MinistryProfile, ChurchProfile
from angelos.document.statements import Verified, Trusted, Revoked


class Portfolio:
    """Collection of public documents belonging and related to an entity."""

    def __init__(self, docs: set):
        self.__docs = docs

    def documents(self) -> set:
        """Portfolio original documents."""
        return self.__docs

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
        docs = self._get_type(self.__docs, types)
        return docs.pop() if docs else None

    def _get_subset(self, types) -> set:
        docs = self._get_type(self.__docs, types)
        return docs if docs else set()

    def __eq__(self, other):
        return collections.Counter(self.__docs) == collections.Counter(other.documents())

    def __str__(self):
        issuer = self._get_issuer(self.__docs)
        owner = self._get_owner(self.__docs)
        output = ""

        for doc in issuer:
            output += doc.__class__.__name__ + "\n"
            output += pprint.pformat(doc.export_yaml()) + "\n\n"

        for doc in owner:
            output += doc.__class__.__name__ + "\n"
            output += pprint.pformat(doc.export_yaml()) + "\n\n"

        return output

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


class PrivatePortfolio(Portfolio):
    """Private documents of an entity."""

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


class Operations:
    """Operations carried out on a portfolio, policies applied."""

    @staticmethod
    def validate(portfolio: Portfolio):
        """Validate all the documents in the portfolio."""

        "portfolio.entity"
        # TODO: policy, portfolio must have entity document.
        # TODO: policy, portfolio must not have several entity documents.
        # TODO: policy, entity document must not be expired.
        "portfolio.keys"
        # TODO: policy, portfolio must have keys document.
        # TODO: policy, portfolio may have several keys document.
        # TODO: policy, at least one keys must not be expired.
        # TODO: policy, keys must not be older than three years.
        "portfolio.network"
        # TODO: policy, portfolio may have network document.
        # TODO: policy, portfolio must not have several network documents.
        # TODO: policy, network document must not be expired.
        "portfolio.profile"
        # TODO: policy, portfolio may have profile document.
        # TODO: policy, portfolio must not have several profile documents.
        # TODO: policy, profile document must match entity document by designated type.
        # TODO: policy, profile document may not be expired.

        "portfolio.verified_issuer"
        "portfolio.trusted_issuer"
        "portfolio.revoked_issuer"
        "portfolio.verified_owner"
        "portfolio.trusted_owner"
        "portfolio.revoked_owner"
        # TODO: policy, portfolio may have several statement documents
        # TODO: policy, portfolio entity must be owner or issuer of statements.
        # TODO: policy, statement documents must not be older than three years.
        # TODO: policy, statement documents may be expired.

        "portfolio.privkeys"
        # TODO: policy, private portfolio must have privkeys document.
        # TODO: policy, private portfolio must not have several privkeys documents.
        # TODO: policy, private privkeys document must not be expired.
        "portfolio.domain"
        # TODO: policy, private portfolio must have domain document.
        # TODO: policy, private portfolio must not have several domain documents.
        # TODO: policy, domain document must not be expired.
        "portfolio.nodes"
        # TODO: policy, private portfolio must have nodes document.
        # TODO: policy, private portfolio may have several nodes document.
        # TODO: policy, nodes must not be expired.
