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
"""Module docstring."""
import copy
import datetime
import logging
import uuid
from abc import ABC, abstractmethod
from typing import Set, Union

from angelos.document.document import Document
from angelos.document.domain import Domain, Node, Network
from angelos.document.entities import Person, Ministry, Church, PrivateKeys, Keys
from angelos.document.envelope import Envelope
from angelos.document.messages import Note, Instant, Mail
from angelos.document.profiles import PersonProfile, MinistryProfile, ChurchProfile
from angelos.document.statements import Verified, Trusted, Revoked
from angelos.document.types import EntityT, DocumentT, StatementT, MessageT
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.entity import PersonPolicy, MinistryPolicy, ChurchPolicy
from angelos.lib.policy.policy import Policy, BasePolicy, BasePolicyMixin
from angelos.lib.policy.portfolio import Portfolio
from angelos.common.utils import Util
from angelos.lib.validation import Rep as Report


class ImportPolicy(Policy):
    """Validate documents before import to facade."""

    def __init__(self, portfolio: Portfolio):
        self.__portfolio = portfolio

    def entity(self) -> (EntityT, Keys):
        """Validate entity for import, use internal portfolio."""
        valid = True
        entity = self.__portfolio.entity
        keys = Crypto.latest_keys(self.__portfolio.keys)

        today = datetime.date.today()
        valid = False if entity.expires < today else valid
        valid = False if keys.expires < today else valid

        valid = False if not entity.validate() else valid
        valid = False if not keys.validate() else valid
        if datetime.date.today() > entity.expires:
            valid = False

        valid = False if not Crypto.verify(keys, self.__portfolio) else valid
        valid = False if not Crypto.verify(entity, self.__portfolio) else valid

        if valid:
            return entity, keys
        else:
            return None, None

    def issued_document(self, document: DocumentT) -> DocumentT:
        """Validate document issued by internal portfolio."""
        Util.is_type(
            document,
            (
                Revoked,
                Trusted,
                Verified,
                PersonProfile,
                MinistryProfile,
                ChurchProfile,
                Domain,
                Network,
                Keys,
                PrivateKeys,
            ),
        )
        if document is None:
            return document

        valid = True
        if document.issuer != self.__portfolio.entity.id:
            valid = False
        if datetime.date.today() > document.expires:
            valid = False
        valid = False if not document.validate() else valid
        valid = (
            False
            if not Crypto.verify(document, self.__portfolio)
            else valid
        )

        if valid:
            return document
        else:
            return None

    def _filter_set(self, documents: Set[DocumentT]) -> Set[DocumentT]:
        removed = set()
        for doc in documents:
            if doc and not self.issued_document(doc):
                removed.add(doc)

        documents -= removed
        return removed

    def node_document(self, node: Node) -> DocumentT:
        """Validate document issued by internal portfolio."""
        if node is None:
            return node

        valid = True
        if node.issuer != self.__portfolio.entity.id:
            valid = False
        if node.domain != self.__portfolio.domain.id:
            valid = False
        if datetime.date.today() > node.expires:
            valid = False
        valid = False if not node.validate() else valid
        valid = (
            False if not Crypto.verify(node, self.__portfolio) else valid
        )

        if valid:
            return node
        else:
            return None

    def owned_document(
        self, issuer: Portfolio, document: StatementT
    ) -> StatementT:
        """Validate document owned by internal portfolio."""
        Util.is_type(document, (Revoked, Trusted, Verified))
        if document is None:
            return document

        valid = True
        if document.owner != self.__portfolio.entity.id:
            valid = False
        if document.issuer != issuer.entity.id:
            valid = False
        if datetime.date.today() > document.expires:
            valid = False
        valid = False if not document.validate() else valid
        valid = (
            False
            if not Crypto.verify(document, issuer.entity, issuer.keys)
            else valid
        )

        if valid:
            return document
        else:
            return None

    def envelope(self, sender: Portfolio, envelope: Envelope) -> Envelope:
        """Validate an envelope addressed to the internal portfolio."""
        Util.is_type(envelope, Envelope)
        valid = True

        if envelope.owner != self.__portfolio.entity.id:
            valid = False
        if envelope.issuer != sender.entity.id:
            valid = False
        if datetime.date.today() > envelope.expires:
            valid = False
        valid = False if not envelope.validate() else valid
        valid = (
            False
            if not Crypto.verify(envelope, sender, exclude=["header"])
            else valid
        )

        if valid:
            return envelope
        else:
            return None

    def message(self, sender: Portfolio, message: MessageT) -> MessageT:
        """Validate a message addressed to the internal portfolio."""
        Util.is_type(message, (Note, Instant, Mail))
        valid = True
        if message.owner != self.__portfolio.entity.id:
            valid = False
        if message.issuer != sender.entity.id:
            valid = False
        if datetime.date.today() > message.expires:
            valid = False
        valid = False if not message.validate() else valid
        valid = False if not Crypto.verify(message, sender) else valid

        if valid:
            return message
        else:
            return None


class ImportUpdatePolicy(Policy):
    """Policy for accepting updateable documents."""

    def __init__(self, portfolio: Portfolio):
        self.__portfolio = portfolio

    def keys(self, newkeys: Keys):
        """Validate newkey generated keys."""
        valid = True

        if newkeys.issuer != self.__portfolio.entity.id:
            valid = False
        if datetime.date.today() > newkeys.expires:
            valid = False
        valid = False if not newkeys.validate() else valid

        # Validate new key with old keys
        valid = (
            False if not Crypto.verify(newkeys, self.__portfolio) else valid
        )

        # Validate new key with itself
        portfolio = copy.deepcopy(self.__portfolio)
        portfolio.keys = set(newkeys)
        valid = False if not Crypto.verify(newkeys, portfolio) else valid

        return valid

    def __dict_cmp(self, entity, fields):
        valid = True

        valid = False if datetime.date.today() > entity.expires else valid
        valid = False if not entity.validate() else valid
        valid = False if not Crypto.verify(entity, self.__portfolio) else valid

        diff = []
        new_exp = entity.export()
        old_exp = self.__portfolio.entity.export()

        for item in new_exp.keys():
            if new_exp[item] != old_exp[item]:
                diff.append(item)

        if len(set(diff) - set(fields + ("signature", "updated"))):
            valid = False

        return valid

    def entity(self, entity: EntityT):
        """Validate updated entity."""
        if isinstance(entity, Person):
            fields = PersonPolicy.FIELDS
        elif isinstance(entity, Ministry):
            fields = MinistryPolicy.FIELDS
        elif isinstance(entity, Church):
            fields = ChurchPolicy.FIELDS

        valid = self.__dict_cmp(entity, fields)

        return valid


class BasePortfolioPolicy(BasePolicy, BasePolicyMixin, ABC):
    """Base class for portfolio policies."""

    def __init__(self, portfolio: Portfolio):
        self.portfolio = portfolio


class EntityKeysPortfolioValidatePolicy(BasePortfolioPolicy):
    """0I-0000: Check that an entity and key pair in a portfolio validates. Entity and keys must validate."""

    def _check_entity_and_keys(self):
        if not isinstance(self.portfolio.entity, (Person, Ministry, Church)):
            raise RuntimeWarning("There is no entity in the portfolio or of wrong type.")
        if not self.portfolio.keys:
            raise RuntimeWarning("There is no public keys in the portfolio.")

        entity = self.portfolio.entity
        keys = Crypto.latest_keys(self.portfolio.keys)

        if not isinstance(keys, Keys):
            raise RuntimeWarning("The latest public key is of wrong type.")

        if entity.is_expired():
            raise RuntimeWarning("Entity document is expired.")
        if keys.is_expired():
            raise RuntimeWarning("Latest Keys document is expired.")

        if not entity.validate():
            raise RuntimeWarning("Entity document doesn't validate.")
        if not keys.validate():
            raise RuntimeWarning("Latest Keys document doesn't validate.")

        if not Crypto.verify(entity, self.portfolio):
            raise RuntimeWarning("Entity document doesn't cryptographically verify.")
        if not Crypto.verify(keys, self.portfolio):
            raise RuntimeWarning("Latest Keys document doesn't cryptographically verify.")

        return True

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        """Apply rules."""
        identity = self.portfolio.entity.id if self.portfolio.entity else identity
        rules = [
            (self._check_entity_and_keys, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class BaseDocumentPortfolioPolicy(BasePortfolioPolicy, ABC):
    """Base class for portfolio issued document policies."""

    TYPES = (Document,)

    def __init__(self, portfolio: Portfolio):
        BasePortfolioPolicy.__init__(self, portfolio)
        self.document = None

    def _check_type(self):
        """Validate that the document is of type defined in self.TYPES"""
        if not isinstance(self.document, self.TYPES):
            raise RuntimeWarning("The document is of wrong type.")

        return True

    def _check_document_validity(self):
        """Validate document validity based on: expiry date passed, all fields validate."""

        if self.document.is_expired():
            raise RuntimeWarning("Document is expired.")

        if not self.document.validate():
            raise RuntimeWarning("Document doesn't validate.")

        return True

    def validate_document(self, document: DocumentT, report: Report = None):
        """Receive a document to be validated against the portfolio.

        Args:
            document (DocumentT):
                Document to validate.
            report (Report):
                The journal to write to.

        Returns (bool):
            The validation result.

        """
        self.document = document
        return self._validator(self, report)

    def validate_all(self, documents: Union[DocumentT, Set[DocumentT]]) -> Report:
        """Validate a batch of documents against the portfolio.

        Args:
            documents (Set[DocumentT()]):
                Documents to be validated in batch.

        Returns (Report):
            Report with the batch result.

        """
        if not isinstance(documents, set):
            documents = set([documents])

        valid = True
        report = Report(self)

        for doc in documents:
            valid = valid if self.validate_document(doc, report) else False
        self.document = None

        if valid and len(report.failed):
            raise RuntimeError("Inaccurate report of failures and validation success.")

        return report


class IssuedDocumentPortfolioValidatePolicy(BaseDocumentPortfolioPolicy):
    """0I-0000: Check that documents issued by a portfolio validate.
    Issued documents must validate with the portfolio.

    This policy expects EntityKeysPortfolioValidatePolicy to apply."""

    TYPES = (
        Revoked, Trusted, Verified, PersonProfile, MinistryProfile,
        ChurchProfile, Domain, Network, Keys, PrivateKeys
    )

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_portfolio(self):
        """Validate the document as cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        """Apply rules."""
        identity = self.document.id if self.document else identity
        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_portfolio, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class NodePortfolioValidatePolicy(IssuedDocumentPortfolioValidatePolicy):
    """0I-0000: Check that nodes issued by a portfolio has a domain and validate.
    Issued nodes must validate with the portfolio domain.

    This policy expects the portfolio to have valid domain document."""

    TYPES = (Node,)

    def _check_domain_of_node(self):
        """Validated that the document is a node of the portfolio domain."""
        if self.document.domain != self.portfolio.domain.id:
            raise RuntimeWarning("The document is not a node of the portfolio domain.")

        return True

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        """Apply rules."""
        identity = self.document.id if self.document else identity
        rules = [
            (self._check_domain_of_node, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class NewKeysPortfolioValidatePolicy(IssuedDocumentPortfolioValidatePolicy):
    """0I-0000: Check that a new key issued by a portfolio cryptographically verifies with itself and older key.
    New keys must verify with an existing portfolio key..

    This policy expects the portfolio to have an older key."""

    TYPES = (Keys,)

    def _check_portfolio_key_update(self):
        if not Crypto.verify_keys(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        """Apply rules."""
        identity = self.document.id if self.document else identity
        rules = [
            (self._check_portfolio_key_update, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class OwnedDocumentPortfolioPolicy(BaseDocumentPortfolioPolicy):
    """0I-0000: Check that owned documents issued by an issuing portfolio validate and is linked to portfolio.
    Issued documents must validate with the portfolio and issuer."""

    TYPES = (
        Revoked, Trusted, Verified,
        Envelope,
        Note, Instant, Mail
    )

    def __init__(self, portfolio: Portfolio):
        BaseDocumentPortfolioPolicy.__init__(self, portfolio)
        self.issuer = None

    def _check_owner_issuer(self):
        """Check that the portfolio is the owner and the issuer the issue."""
        if self.document.owner != self.portfolio.entity.id:
            raise RuntimeWarning("Document not owned by internal portfolio.")
        if self.document.issuer != self.issuer.entity.id:
            raise RuntimeWarning("Document not issued by issuing portfolio.")

    def _check_verified_issuer(self):
        """Check the document as cryptographically verified against issuing portfolio."""
        if not Crypto.verify(self.document, self.issuer):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        """Apply rules."""
        identity = self.document.id if self.document else identity
        rules = [
            (self._check_type, b'I', 0),
            (self._check_owner_issuer, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_issuer, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class BaseDocumentUpdatePortfolioPolicy(BasePortfolioPolicy, ABC):
    """Base class for importing updated documents to portfolio policies."""

    TYPES = (Document,)

    def __init__(self, portfolio: Portfolio):
        BasePortfolioPolicy.__init__(self, portfolio)
        self.document = None

    @abstractmethod
    def _import_doc(self, doc: DocumentT):
        """Abstract function for importing document to portfolio."""
        pass

    def _check_type(self):
        """Validate that the document is of type defined in self.TYPES"""
        if not isinstance(self.document, self.TYPES):
            raise RuntimeWarning("The document is of wrong type.")

        return True

    def _check_document_validity(self):
        """Validate document validity based on: expiry date passed, all fields validate."""

        if self.document.is_expired():
            raise RuntimeWarning("Document is expired.")

        if not self.document.validate():
            raise RuntimeWarning("Document doesn't validate.")

        return True

    def validate_document(self, document: DocumentT, report: Report = None):
        """Receive a document to be validated against the portfolio.

        Args:
            document (DocumentT):
                Document to validate.
            report (Report):
                The journal to write to.

        Returns (bool):
            The validation result.

        """
        self.document = document
        return self._validator(self, report)

    def validate_all(self, documents: Union[DocumentT, Set[DocumentT]]) -> Report:
        """Validate a batch of documents against the portfolio.

        Args:
            documents (Set[DocumentT()]):
                Documents to be validated in batch.

        Returns (Report):
            Report with the batch result.

        """
        if not isinstance(documents, set):
            documents = set([documents])

        valid = True
        report = Report(self)

        for doc in documents:
            success = self.validate_document(doc, report)
            valid = valid if success else False
            if success:
                self._import_doc(doc)
        self.document = None

        if valid and len(report.failed):
            raise RuntimeError("Inaccurate report of failures and validation success.")

        return report


class KeysImportPortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    TYPES = (Keys,)

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_keys(self):
        """Check the key is cryptographically verified against internal portfolio."""
        if not Crypto.verify_keys(self.document, self.portfolio):
            raise RuntimeWarning("Key document doesn't cryptographically verify.")

        return True

    def _import_doc(self, doc: DocumentT):
        if not self.document in self.portfolio.keys:
            self.portfolio.keys.add(doc)

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_keys, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class PrivateKeysImportPortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    TYPES = (PrivateKeys,)

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_keys(self):
        """Check the key is cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Key document doesn't cryptographically verify.")

        return True

    def _import_doc(self, doc: DocumentT):
            self.portfolio.privkeys = doc

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_keys, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class StatementImportPortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    TYPES = (Revoked, Trusted, Verified)

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_portfolio(self):
        """Validate the document as cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def _import_doc(self, doc: DocumentT):
        if isinstance(doc, Revoked):
            if not self.document in self.portfolio.issuer.revoked:
                self.portfolio.issuer.revoked.add(doc)
        if isinstance(doc, Trusted):
            if not self.document in self.portfolio.issuer.trusted:
                self.portfolio.issuer.trusted.add(doc)
        if isinstance(doc, Verified):
            if not self.document in self.portfolio.issuer.verified:
                self.portfolio.issuer.verified.add(doc)

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_portfolio, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class EntityUpdatePortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    """Update the entity of the profile checking changes, validating and verifying."""
    TYPES = (Person, Ministry, Church)

    def __init__(self, portfolio: Portfolio):
        BaseDocumentUpdatePortfolioPolicy.__init__(self, portfolio)
        self.original = None

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_portfolio(self):
        """Validate the document as cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def _check_document_change(self):
        """Validate that unchangeable fields of a changeable document are the same."""
        if not self.original.compare(self.document):
            raise RuntimeWarning("Document is not the same.")

        exclude = ["signature", "updated"] + list(self.document.changeables())
        if hash(Crypto.document_data(self.document, exclude)) != hash(Crypto.document_data(self.original, exclude)):
            raise RuntimeWarning("Document has changed unchangeable fields.")

    def _import_doc(self, doc: DocumentT):
        self.portfolio.entity = self.original

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        self.original = self.portfolio.entity

        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_change, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_portfolio, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class ProfileUpdatePortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    """Update the entity of the profile checking changes, validating and verifying."""
    TYPES = (PersonProfile, MinistryProfile, ChurchProfile)

    def __init__(self, portfolio: Portfolio):
        BaseDocumentUpdatePortfolioPolicy.__init__(self, portfolio)
        self._original = None

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_portfolio(self):
        """Validate the document as cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def _check_document_change(self):
        """Validate that unchangeable fields of a changeable document are the same."""
        if not self.original.compare(self.document):
            raise RuntimeWarning("Document is not the same.")

        exclude = ["signature", "updated"] + list(self.document.changeables())
        if hash(Crypto.document_data(self.document, exclude)) != hash(Crypto.document_data(self.original, exclude)):
            raise RuntimeWarning("Document has changed unchangeable fields.")

    def _import_doc(self, doc: DocumentT):
        self.portfolio.profile = self.original

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        self.original = self.portfolio.profile

        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_change, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_portfolio, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class NetworkUpdatePortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    """Update the entity of the network checking changes, validating and verifying."""
    TYPES = (Network, )

    def __init__(self, portfolio: Portfolio):
        BaseDocumentUpdatePortfolioPolicy.__init__(self, portfolio)
        self.original = None

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_portfolio(self):
        """Validate the document as cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def _check_document_change(self):
        """Validate that unchangeable fields of a changeable document are the same."""
        if not self.original.compare(self.document):
            raise RuntimeWarning("Document not the same as original.")

        exclude = ["signature", "updated"] + list(self.document.changeables())
        if hash(Crypto.document_data(self.document, exclude)) != hash(Crypto.document_data(self.original, exclude)):
            raise RuntimeWarning("Document has changed unchangeable fields.")

    def _import_doc(self, doc: DocumentT):
        self.portfolio.network = self.original

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        self.original = self.portfolio.network

        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_change, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_portfolio, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class NodeUpdatePortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    """Update the entity of the network checking changes, validating and verifying."""
    TYPES = (Node, )

    def __init__(self, portfolio: Portfolio):
        BaseDocumentUpdatePortfolioPolicy.__init__(self, portfolio)
        self.original = None

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_portfolio(self):
        """Validate the document as cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def _check_document_update(self):
        """Validate that unchangeable fields of an updatable document are the same."""
        if not self.original.compare(self.document):
            raise RuntimeWarning("Document not the same as original.")

        exclude = ["signature", "updated"]
        if hash(Crypto.document_data(self.document, exclude)) != hash(Crypto.document_data(self.original, exclude)):
            raise RuntimeWarning("Document has changed fields.")

    def _import_doc(self, doc: DocumentT):
        self.portfolio.nodes.remove(self.original)
        self.portfolio.nodes.add(self.document)

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        self.original = self.portfolio.network

        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_update, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_portfolio, b'I', 0)
        ]
        return self._checker(rules, report, identity)


class DomainUpdatePortfolioPolicy(BaseDocumentUpdatePortfolioPolicy):
    """Update the entity of the network checking changes, validating and verifying."""
    TYPES = (Domain, )

    def __init__(self, portfolio: Portfolio):
        BaseDocumentUpdatePortfolioPolicy.__init__(self, portfolio)
        self.original = None

    def _check_issuer(self):
        """Validate that the document is issued by the internal portfolio."""
        if self.document.issuer != self.portfolio.entity.id:
            raise RuntimeWarning("The document is not issued by this portfolio.")

        return True

    def _check_verified_portfolio(self):
        """Validate the document as cryptographically verified against internal portfolio."""
        if not Crypto.verify(self.document, self.portfolio):
            raise RuntimeWarning("Document doesn't cryptographically verify.")

        return True

    def _check_document_update(self):
        """Validate that unchangeable fields of an updatable document are the same."""
        if not self.original.compare(self.document):
            raise RuntimeWarning("Document not the same as original.")

        exclude = ["signature", "updated"]
        if hash(Crypto.document_data(self.document, exclude)) != hash(Crypto.document_data(self.original, exclude)):
            raise RuntimeWarning("Document has changed fields.")

    def _check_document_newer(self):
        """Validate that teh document is newer than the original."""
        if not self.document > self.original:
            raise RuntimeWarning("Document not newer than the original.")

    def _import_doc(self, doc: DocumentT):
        self.portfolio.domain = self.original

    def apply_rules(self, report: Report = None, identity: uuid.UUID = Report.NULL_IDENTITY):
        identity = self.document.id if self.document else identity
        self.original = self.portfolio.network

        rules = [
            (self._check_type, b'I', 0),
            (self._check_issuer, b'I', 0),
            (self._check_document_update, b'I', 0),
            (self._check_document_validity, b'I', 0),
            (self._check_verified_portfolio, b'I', 0),
            (self._check_document_newer, b'I', 0)  # FIXME: Add to all single document update policies
        ]
        return self._checker(rules, report, identity)