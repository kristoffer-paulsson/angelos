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
from typing import Tuple

from angelos.bin.nacl import DualSecret
from angelos.common.policy import PolicyPerformer, PolicyMixin, policy, PolicyException
from angelos.document.entities import PrivateKeys, Keys
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio


class BaseNewKeys(PolicyPerformer):
    """Initialize the new keys generator."""
    def __init__(self):
        super().__init__()
        self._portfolio = None
        self._keys = None
        self._privkeys = None

    def _setup(self):
        self._keys = None
        self._privkeys = None

    def _clean(self):
        pass


class NewKeysMixin(PolicyMixin):
    """Logic for generating new Keys and PrivateKeys for an existing PrivatePortfolio."""

    def apply(self) -> bool:
        """Perform logic to generate new keys with its new portfolio."""
        box = DualSecret()

        self._privkeys = PrivateKeys(nd={
            "issuer": self._portfolio.entity.id,
            "secret": box.sk,
            "seed": box.seed,
        })
        self._keys = Keys(nd={
            "issuer": self._portfolio.entity.id,
            "public": box.pk,
            "verify": box.vk,
        })

        self._privkeys = Crypto.sign(self._privkeys, self._portfolio, multiple=True)
        self._keys = Crypto.sign(self._keys, self._portfolio, multiple=True)
        portfolio = PrivatePortfolio({self._portfolio.entity, self._privkeys, self._keys}, frozen=False)
        self._privkeys = Crypto.sign(self._privkeys, portfolio, multiple=True)
        self._keys = Crypto.sign(self._keys, portfolio, multiple=True)

        if not all([
                self._privkeys.validate(),
                self._keys.validate(),
                Crypto.verify(self._privkeys, self._portfolio),
                Crypto.verify(self._keys, self._portfolio),
                Crypto.verify(self._privkeys, portfolio),
                Crypto.verify(self._keys, portfolio)
            ]):
            raise PolicyException()

        docs = portfolio.documents()
        docs |= (self._portfolio.filter(portfolio.documents()) - {self._portfolio.privkeys})
        self._portfolio.__init__(docs)
        return True


class NewKeys(BaseNewKeys, NewKeysMixin):
    """Generate new keys and privkeys document of a portfolio."""

    @policy(b'I', 0, "Keys:New")
    def perform(self, portfolio: PrivatePortfolio) -> Tuple[Keys, PrivateKeys]:
        """Perform new key for portfolio."""
        self._portfolio = portfolio
        self._applier()
        return self._keys, self._privkeys