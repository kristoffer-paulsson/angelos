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
"""Creating new entity portfolio for Person, Ministry and Church including Keys and PrivateKeys documents."""
from angelos.common.policy import PolicyMixin, policy, PolicyException, PolicyValidator
from angelos.document.entities import Entity, Keys, PrivateKeys
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import Portfolio, PrivatePortfolio
from angelos.portfolio.policy import DocumentPolicy, UpdatablePolicy


class AcceptEntity(DocumentPolicy, PolicyValidator, PolicyMixin):
    """Valid an entity and its keys."""

    def _setup(self):
        pass

    def _clean(self):
        self._document = None

    @policy(b'I', 0)
    def _check_entity_keys_overlap(self) -> bool:
        keys = Crypto.latest_keys(self._portfolio.keys)
        touched = self._portfolio.entity.get_touched()

        if not keys.created <= touched and keys.expires >= touched:
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate a new entity with its keys."""
        self._document = self._portfolio.entity
        valid = [
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]

        self._document = Crypto.latest_keys(self._portfolio.keys)
        valid += [
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]

        valid += [
            self._check_entity_keys_overlap()
        ]

        if not all(valid):
            raise PolicyException()
        return True

    @policy(b'I', 0, "Entity:Accept")
    def validate(self, portfolio: Portfolio) -> bool:
        """Perform validation of entity and keys from portfolio."""
        self._portfolio = portfolio
        self._applier()
        return True


class AcceptUpdatedEntity(UpdatablePolicy, PolicyValidator, PolicyMixin):
    """Validate an entity."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None
        self._former = None

    def apply(self) -> bool:
        """Perform logic to validate updated entity with current."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_fields_unchanged()
        ]):
            raise PolicyException()

        self._update()
        return True

    @policy(b'I', 0, "Entity:AcceptUpdated")
    def validate(self, portfolio: Portfolio, entity: Entity) -> bool:
        """Perform validation of entity and keys from portfolio."""
        self._portfolio = portfolio
        self._document = entity
        self._former = portfolio.entity
        self._applier()
        return True


class AcceptNewKeys(DocumentPolicy, PolicyValidator, PolicyMixin):
    """Validate new keys."""

    def _setup(self):
        pass

    def _clean(self):
        self._document = None
        self._portfolio = None

    @policy(b'I', 0)
    def _check_keys_self_verify(self, portfolio:Portfolio) -> bool:
        if not Crypto.verify(self._document, portfolio):
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate new keys."""
        portfolio = Portfolio({self._portfolio.entity, self._document})

        valid = [
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
            self._check_keys_self_verify(portfolio)
        ]
        if not all(valid):
            raise PolicyException()

        self._add()
        return True

    @policy(b'I', 0, "Keys:Accept")
    def validate(self, portfolio: Portfolio, keys: Keys) -> bool:
        """Perform validation of new keys for portfolio."""
        self._portfolio = portfolio
        self._document = keys
        self._applier()
        return True


class AcceptPrivateKeys(UpdatablePolicy, PolicyValidator, PolicyMixin):
    """Validate private keys."""

    def _setup(self):
        pass

    def _clean(self):
        self._portfolio = None
        self._document = None
        self._privkeys = None

    def apply(self) -> bool:
        """Perform logic to validate private keys."""
        if not all([
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]):
            raise PolicyException()

        self._update()
        return True

    @policy(b'I', 0, "PrivateKeys:Accept")
    def validate(self, portfolio: PrivatePortfolio, privkeys: PrivateKeys) -> bool:
        """Perform validation of updated domain for portfolio."""
        self._portfolio = portfolio
        self._document = privkeys
        self._former = portfolio.privkeys
        self._applier()
        return True