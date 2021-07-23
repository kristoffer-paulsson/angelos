# cython: language_level=3, linetrace=True
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
import datetime

from angelos.document.entities import PrivateKeys, Keys, Person, Ministry, Church
from angelos.document.types import EntityT
from angelos.bin.nacl import DualSecret
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.policy import Policy
from angelos.lib.policy.portfolio import PrivatePortfolio
from angelos.lib.policy.types import (
    EntityDataT,
    PersonData,
    MinistryData,
    ChurchData,
    PrivatePortfolioABC,
)


class BaseEntityPolicy(Policy):
    def __init__(self):
        self._box = None

    @staticmethod
    def _generate(klass, entity_data: EntityDataT) -> PrivatePortfolio:
        box = DualSecret()

        entity = klass(nd=dict(entity_data._asdict()))
        entity.issuer = entity.id
        entity.signature = box.signature(
            entity.issuer.bytes + Crypto.document_data(entity)
        )

        privkeys = PrivateKeys(
            nd={"issuer": entity.id, "secret": box.sk, "seed": box.seed}
        )
        privkeys.signature = box.signature(
            privkeys.issuer.bytes + Crypto.document_data(privkeys)
        )

        keys = Keys(
            nd={"issuer": entity.id, "public": box.pk, "verify": box.vk}
        )
        keys.signature = [
            box.signature(keys.issuer.bytes + Crypto.document_data(keys))
        ]

        entity.validate()
        privkeys.validate()
        keys.validate()

        portfolio = PrivatePortfolio()
        portfolio.entity = entity
        portfolio.privkeys = privkeys
        portfolio.keys.add(keys)

        return portfolio

    @staticmethod
    def update(portfolio: PrivatePortfolio) -> bool:
        """Renew the identity document expiry date"""

        entity = portfolio.entity
        today = datetime.date.today()
        # entity = copy.deepcopy(entity)
        entity.updated = today
        entity.expires = today + datetime.timedelta(13 * 365 / 12)
        entity._fields["signature"].redo = True
        entity.signature = None

        entity = Crypto.sign(entity, portfolio)
        entity.validate()
        portfolio.entity = entity

        return True

    @staticmethod
    def _change(entity: EntityT, changed: dict, allowed: list) -> bool:
        """
        Change information on the identity.
        Don't forget to update the change.
        """
        fields = set(allowed)
        args = set(changed.keys())

        if len(args - fields):
            raise IndexError()

        for name, field in changed.items():
            setattr(entity, name, field)

        return True

    @staticmethod
    def newkeys(portfolio: PrivatePortfolio) -> bool:
        """Issue a new pair of keys"""
        box = DualSecret()

        new_pk = PrivateKeys(
            nd={
                "issuer": portfolio.entity.id,
                "secret": box.sk,
                "seed": box.seed,
            }
        )
        # Sign new private key with latest private key
        # TODO: Private keys should be double signed like new public keys.
        new_pk = Crypto.sign(new_pk, portfolio)

        new_keys = Keys(
            nd={
                "issuer": portfolio.entity.id,
                "public": box.pk,
                "verify": box.vk,
            }
        )
        # sign new public key with old and new private key, REWRITE
        #  FIXME: REWRITE the signing of new public keys
        new_keys = Crypto.sign(
            new_keys,
            portfolio.entity,
            portfolio.privkeys,
            portfolio.keys,
            multiple=True,
        )
        new_keys = Crypto.sign(
            new_keys, portfolio.entity, new_pk, new_keys, multiple=True
        )

        new_pk.validate()
        new_keys.validate()

        portfolio.privkeys = new_pk
        portfolio.keys.add(new_keys)

        return True


class PersonPolicy(BaseEntityPolicy):
    """Create and maintain Person entity document with keys."""

    FIELDS = ("family_name",)

    @staticmethod
    def generate(person_data: PersonData) -> PrivatePortfolio:
        return BaseEntityPolicy._generate(Person, person_data)

    @staticmethod
    def change(portfolio: PrivatePortfolio, changed: dict) -> bool:
        return BaseEntityPolicy._change(
            portfolio.entity, changed, PersonPolicy.FIELDS
        )


class MinistryPolicy(BaseEntityPolicy):
    """Create and maintain Ministry entity document with keys."""

    FIELDS = ("vision", "ministry")

    @staticmethod
    def generate(ministry_data: MinistryData) -> PrivatePortfolio:
        return BaseEntityPolicy._generate(Ministry, ministry_data)

    @staticmethod
    def change(portfolio: PrivatePortfolio, changed: dict) -> bool:
        return BaseEntityPolicy._change(
            portfolio.entity, changed, MinistryPolicy.FIELDS
        )


class ChurchPolicy(BaseEntityPolicy):
    """Create and maintain Church entity document with keys."""

    FIELDS = ("state", "nation")

    @staticmethod
    def generate(church_data: ChurchData) -> PrivatePortfolio:
        return BaseEntityPolicy._generate(Church, church_data)

    @staticmethod
    def change(portfolio: PrivatePortfolio, changed: dict) -> bool:
        return BaseEntityPolicy._change(
            portfolio.entity, changed, ChurchPolicy.FIELDS
        )
