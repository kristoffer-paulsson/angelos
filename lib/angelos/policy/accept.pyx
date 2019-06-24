# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
import datetime
import copy
import logging

from typing import Set

from ..utils import Util
from ..document import (
    Entity, Person, Ministry, Church, Keys, Statement, Domain, Node, Network,
    Envelope, Message, Document, PrivateKeys, Revoked, Trusted, Verified,
    PersonProfile, MinistryProfile, ChurchProfile, Note, Instant, Mail)
from .entity import (
    PersonPolicy, MinistryPolicy, ChurchPolicy)
from .crypto import Crypto
from .portfolio import Portfolio
from .policy import Policy


class ImportPolicy(Policy):
    """Validate documents before import to facade."""
    def __init__(self, portfolio: Portfolio):
        self._portfolio = portfolio

    def entity(self) -> (Entity, Keys):
        """Validate entity for import, use internal portfolio."""
        valid = True
        entity = self._portfolio.entity
        keys = Crypto._latestkeys(self._portfolio.keys)

        today = datetime.date.today()
        valid = False if entity.expires < today else valid
        valid = False if keys.expires < today else valid

        try:
            valid = False if not entity.validate() else valid
            valid = False if not keys.validate() else valid
            if datetime.date.today() > entity.expires:
                valid = False
        except Exception as e:
            logging.info('%s' % str(e))
            valid = False

        valid = False if not Crypto.verify(keys, self._portfolio) else valid
        valid = False if not Crypto.verify(entity, self._portfolio) else valid

        if valid:
            return entity, keys
        else:
            return None, None

    def issued_document(self, document: Document) -> Document:
        """Validate document issued by internal portfolio."""
        Util.is_type(document, (
            Revoked, Trusted, Verified, PersonProfile, MinistryProfile,
            ChurchProfile, Domain, Network, Keys, PrivateKeys))
        if document is None:
            return document

        valid = True
        try:
            if document.issuer != self._portfolio.entity.id:
                valid = False
            if datetime.date.today() > document.expires:
                valid = False
            valid = False if not document.validate() else valid
            valid = False if not Crypto.verify(
                document, self._portfolio) else valid
        except Exception as e:
            logging.info('%s' % str(e))
            valid = False

        if valid:
            return document
        else:
            return None

    def _filter_set(self, documents: Set[Document]) -> Set[Document]:
        removed = set()
        for doc in documents:
            if doc and not self.issued_document(doc):
                removed.add(doc)

        documents -= removed
        return removed

    def node_document(self, node: Node) -> Document:
        """Validate document issued by internal portfolio."""
        if node is None:
            return node

        valid = True
        try:
            if node.issuer != self._portfolio.entity.id:
                valid = False
            if node.domain != self._portfolio.domain.id:
                valid = False
            if datetime.date.today() > node.expires:
                valid = False
            valid = False if not node.validate() else valid
            valid = False if not Crypto.verify(
                node, self._portfolio) else valid
        except Exception as e:
            logging.info('%s' % str(e))
            valid = False

        if valid:
            return node
        else:
            return None

    def owned_document(
            self, issuer: Portfolio, document: Statement) -> Statement:
        """Validate document owned by internal portfolio."""
        Util.is_type(document, (Revoked, Trusted, Verified))
        if document is None:
            return document

        valid = True
        try:
            if document.owner != self._portfolio.entity.id:
                valid = False
            if document.issuer != issuer.entity.id:
                valid = False
            if datetime.date.today() > document.expires:
                valid = False
            valid = False if not document.validate() else valid
            valid = False if not Crypto.verify(
                document, issuer.entity, issuer.keys) else valid
        except Exception as e:
            logging.info('%s' % str(e))
            valid = False

        if valid:
            return document
        else:
            return None

    def envelope(self, sender: Portfolio, envelope: Envelope) -> Envelope:
        """Validate an envelope addressed to the internal portfolio."""
        Util.is_type(envelope, Envelope)
        valid = True
        try:
            if envelope.owner != self._portfolio.entity.id:
                valid = False
            if envelope.issuer != sender.entity.id:
                valid = False
            if datetime.date.today() > envelope.expires:
                valid = False
            valid = False if not envelope.validate() else valid
            valid = False if not Crypto.verify(
                envelope, sender, exclude=['header']) else valid
        except Exception as e:
            logging.info('%s' % str(e))
            valid = False

        if valid:
            return envelope
        else:
            return None

    def message(self, sender: Portfolio, message: Message) -> Message:
        """Validate a message addressed to the internal portfolio."""
        Util.is_type(message, (Note, Instant, Mail))
        valid = True
        try:
            if message.owner != self._portfolio.entity.id:
                valid = False
            if message.issuer != sender.entity.id:
                valid = False
            if datetime.date.today() > message.expires:
                valid = False
            valid = False if not message.validate() else valid
            valid = False if not Crypto.verify(message, sender) else valid
        except Exception as e:
            logging.info('%s' % str(e))
            valid = False

        if valid:
            return message
        else:
            return None


class ImportUpdatePolicy(Policy):
    """Policy for accepting updateable documents."""
    def __init__(self, portfolio: Portfolio):
        self._portfolio = portfolio
        self.exception

    def keys(self, newkeys: Keys):
        """Validate newky generated keys."""
        self.exception = None
        valid = True

        try:
            if newkeys.issuer != self._portfolio.entity.id:
                valid = False
            if datetime.date.today() > newkeys.expires:
                valid = False
            valid = False if not newkeys.validate() else valid

            # Validate new key with old keys
            valid = False if not Crypto.verify(
                newkeys, self._portfolio) else valid

            # Validate new key with itself
            portfolio = copy.deepcopy(self._portfolio)
            portfolio.keys = set(newkeys)
            valid = False if not Crypto.verify(
                newkeys, portfolio) else valid

        except Exception as e:
            self.exception = e
            valid = False

        return valid

    def __dict_cmp(self, entity, fields):
        valid = True

        valid = False if datetime.date.today() > entity.expires else valid
        valid = False if not entity.validate() else valid
        valid = False if not Crypto.verify(
            entity, self._portfolio) else valid

        diff = []
        new_exp = entity.export()
        old_exp = self._portfolio.entity.export()

        for item in new_exp.keys():
            if new_exp[item] != old_exp[item]:
                diff.append(item)

        if len(set(diff) - set(fields + ['signature', 'updated'])):
            valid = False

        return valid

    def entity(self, entity: Entity):
        """Validate updated entity."""
        self.exception = None

        if isinstance(entity, Person):
            fields = PersonPolicy.FIELDS
        elif isinstance(entity, Ministry):
            fields = MinistryPolicy.FIELDS
        elif isinstance(entity, Church):
            fields = ChurchPolicy.FIELDS

        try:
            valid = self.__dict_cmp(entity, fields)
        except Exception as e:
            self.exception = e
            valid = False

        return valid
