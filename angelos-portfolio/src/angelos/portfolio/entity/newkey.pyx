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
from typing import Tuple

from angelos.bin.nacl import DualSecret
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.entities import PrivateKeys, Keys
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.policy import DocumentPolicy


class NewKeys(DocumentPolicy, PolicyPerformer, PolicyMixin):
    """Generate new keys and privkeys document of a portfolio."""

    def __init__(self):
        super().__init__()
        self._keys = None
        self._privkeys = None

    def _setup(self):
        self._keys = None
        self._privkeys = None

    def _clean(self):
        pass

    def apply(self) -> bool:
        """Perform logic to generate new keys with its new portfolio."""
        box = DualSecret()
        real = self._portfolio

        self._privkeys = PrivateKeys(nd={
            "issuer": real.entity.id,
            "secret": box.sk,
            "seed": box.seed,
        })
        self._keys = Keys(nd={
            "issuer": real.entity.id,
            "public": box.pk,
            "verify": box.vk,
        })

        self._privkeys = Crypto.sign(self._privkeys, real, multiple=True)
        self._keys = Crypto.sign(self._keys, real, multiple=True)
        temp = PrivatePortfolio({real.entity, self._privkeys, self._keys}, frozen=False)
        self._privkeys = Crypto.sign(self._privkeys, temp, multiple=True)
        self._keys = Crypto.sign(self._keys, temp, multiple=True)

        self._portfolio = real
        self._document = self._privkeys
        valid = [
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]
        self._portfolio = temp
        valid += [self._check_document_verify()]

        self._portfolio = real
        self._document = self._keys
        valid += [
            self._check_document_issuer(),
            self._check_document_expired(),
            self._check_document_valid(),
            self._check_document_verify(),
        ]
        self._portfolio = temp
        valid += [self._check_document_verify()]

        if not all(valid):
            raise PolicyException()

        self._portfolio = real
        docs = temp.documents()
        docs |= (self._portfolio.filter(temp.documents()) - {self._portfolio.privkeys})
        self._portfolio.__init__(docs)
        return True

    @policy(b'I', 0, "Keys:New")
    def perform(self, portfolio: PrivatePortfolio) -> Tuple[Keys, PrivateKeys]:
        """Perform new key for portfolio."""
        self._portfolio = portfolio
        self._applier()
        return self._keys, self._privkeys