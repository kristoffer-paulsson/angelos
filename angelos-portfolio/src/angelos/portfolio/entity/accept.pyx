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
        self._portfolio = None
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
    def validate(self, portfolio: Portfolio):
        """Perform validation of entity and keys from portfolio."""
        self._portfolio = portfolio
        self._applier()
        return self._portfolio
