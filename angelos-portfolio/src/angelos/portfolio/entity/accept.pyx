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
from angelos.portfolio.collection import Portfolio


class BaseValidateEntity(PolicyValidator):
    """Initialize the entity validator"""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._entity = None
        self._keys = None

    def _setup(self):
        self._entity = self._portfolio.entity
        self._keys = Crypto.latest_keys(self._portfolio.keys)

    def _clean(self):
        self._entity = None
        self._keys = None


class ValidateEntityMixin(PolicyMixin):
    """Logic for validating a new Entity and Keys from a Portfolio."""

    @policy(b'I', 0)
    def _check_entity_expired(self) -> bool:
        if self._entity.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_keys_expired(self) -> bool:
        if self._keys.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_entity_valid(self) -> bool:
        if not self._entity.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_keys_valid(self) -> bool:
        if not self._keys.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_entity_verify(self) -> bool:
        if not Crypto.verify(self._entity, self._portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_keys_verify(self) -> bool:
        if not Crypto.verify(self._keys, self._portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_entity_keys_overlap(self) -> bool:
        touched = self._entity.get_touched()
        if not self._keys.created <= touched and self._keys.expires >= touched:
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate a new entity with its keys."""
        if not all([
            self._check_entity_keys_overlap(),
            self._check_entity_expired(),
            self._check_keys_expired(),
            self._check_entity_valid(),
            self._check_keys_valid(),
            self._check_entity_verify(),
            self._check_keys_verify()
        ]):
            raise PolicyException()
        return True


class ValidateEntity(BaseValidateEntity, ValidateEntityMixin):
    """Valid an entity and its keys."""

    @policy(b'I', 0, "Entity:Validate")
    def validate(self, portfolio: Portfolio) -> bool:
        """Perform validation of entity and keys from portfolio."""
        self._portfolio = portfolio
        self._applier()
        return True


class BaseAcceptUpdatedEntity(PolicyValidator):
    """Initialize the updated entity validator."""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._entity = None

    def _setup(self):
        pass

    def _clean(self):
        self._entity = None


class AcceptUpdatedEntityMixin(PolicyMixin):
    """Logic for validating and updated Entity for a Portfolio."""

    @policy(b'I', 0)
    def _check_entity_expired(self) -> bool:
        if self._entity.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_entity_valid(self) -> bool:
        if not self._entity.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_entity_verify(self) -> bool:
        if not Crypto.verify(self._entity, self._portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_entity_morpheme(self) -> bool:
        if not self._entity.morpheme(self._portfolio.entity):
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate updated entity with current."""
        if not all([
            self._check_entity_expired(),
            self._check_entity_valid(),
            self._check_entity_verify(),
            self._check_entity_morpheme()
        ]):
            raise PolicyException()

        docs = self._portfolio.filter({self._portfolio.entity}) | {self._entity}
        self._portfolio.__init__(docs)
        return True


class AcceptUpdatedEntity(BaseAcceptUpdatedEntity, AcceptUpdatedEntityMixin):
    """Validate an entity."""

    @policy(b'I', 0, "Entity:AcceptUpdate")
    def validate(self, portfolio: Portfolio, entity: Entity) -> bool:
        """Perform validation of entity and keys from portfolio."""
        self._portfolio = portfolio
        self._entity = entity
        self._applier()
        return True


class BaseAcceptNewKeys(PolicyValidator):
    """Initialize the new keys validator."""

    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._entity = None
        self._keys = None
        self._privkeys = None

    def _setup(self):
        self._entity = self._portfolio.entity

    def _clean(self):
        self._entity = None
        self._keys = None
        self._privkeys = None


class AcceptNewKeysMixin(PolicyMixin):
    """Logic for validating new keys for a Portfolio."""

    @policy(b'I', 0)
    def _check_keys_issuer(self) -> bool:
        if self._keys.issuer != self._portfolio.entity.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_keys_expired(self) -> bool:
        if self._keys.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_keys_valid(self) -> bool:
        if not self._keys.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_keys_verify(self) -> bool:
        if not Crypto.verify(self._keys, self._portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_keys_self_verify(self, portfolio:Portfolio) -> bool:
        if not Crypto.verify(self._keys, portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_privkeys_issuer(self) -> bool:
        if self._privkeys.issuer != self._portfolio.entity.id:
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_privkeys_expired(self) -> bool:
        if self._privkeys.is_expired():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_privkeys_valid(self) -> bool:
        if not self._privkeys.validate():
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_privkeys_verify(self) -> bool:
        if not Crypto.verify(self._privkeys, self._portfolio):
            raise PolicyException()
        return True

    @policy(b'I', 0)
    def _check_privkeys_self_verify(self, portfolio:Portfolio) -> bool:
        if not Crypto.verify(self._privkeys, portfolio):
            raise PolicyException()
        return True

    def apply(self) -> bool:
        """Perform logic to validate new keys."""
        portfolio = Portfolio({self._portfolio.entity, self._keys})

        valid = [
            self._check_keys_issuer(),
            self._check_keys_expired(),
            self._check_keys_valid(),
            self._check_keys_verify(),
            self._check_keys_self_verify(portfolio)
        ]

        if self._privkeys:
            valid += [
                self._check_privkeys_issuer(),
                self._check_privkeys_expired(),
                self._check_privkeys_valid(),
                self._check_privkeys_verify(),
                self._check_privkeys_self_verify(portfolio)
            ]

        if not all(valid):
            raise PolicyException()

        if self._privkeys:
            docs = {self._keys, self._privkeys} | (self._portfolio.documents() - {self._portfolio.privkeys})
        else:
            docs = {self._keys} | self._portfolio.documents()
        self._portfolio.__init__(docs)
        return True


class AcceptNewKeys(BaseAcceptNewKeys, AcceptNewKeysMixin):
    """Validate new keys."""

    @policy(b'I', 0, "Keys:Accept")
    def validate(self, portfolio: Portfolio, keys: Keys, privkeys: PrivateKeys = None) -> bool:
        """Perform validation of new keys for portfolio."""
        self._portfolio = portfolio
        self._keys = keys
        self._privkeys = privkeys
        self._applier()
        return True