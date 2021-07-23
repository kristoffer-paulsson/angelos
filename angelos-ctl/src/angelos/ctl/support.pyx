# cython: language_level=3, linetrace=True
#
# Copyright (c) 2021 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
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
"""Support classes for the ctl."""
import datetime
import uuid
from pathlib import Path
from types import SimpleNamespace

from angelos.bin.nacl import Signer
from angelos.facade.facade import Facade
from angelos.lib.const import Const
from angelos.lib.policy.crypto import Crypto
from angelos.portfolio.collection import PrivatePortfolio
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio, PersonData


ADMIN_ENTITY = PersonData(**{
    "given_name": "John",
    "names": ["John", "Admin"],
    "family_name": "Roe",
    "sex": "man",
    "born": datetime.date(1970, 1, 1)
})


class AdminFacade(Facade):
    """Client admin facade to be used with the network authentication protocol."""

    @classmethod
    def setup(cls, signer: Signer):
        """Setup the admin facade using a signer."""
        portfolio = SetupPersonPortfolio().perform(ADMIN_ENTITY, role=Const.A_ROLE_PRIMARY, server=False)
        portfolio.privkeys.seed = signer.seed
        list(portfolio.keys)[0].verify = signer.vk

        for doc in portfolio.documents():
            doc._fields["signature"].redo = True
            doc.signature = None

            if doc._fields["signature"].multiple:
                Crypto.sign(doc, portfolio, multiple=True)
            else:
                Crypto.sign(doc, portfolio)

        return cls(Path("~/"), None, portfolio=portfolio, role=Const.A_ROLE_PRIMARY, server=False)

    @classmethod
    def _setup(
            cls, home_dir: Path, secret: bytes, portfolio: PrivatePortfolio,
            vault_type: int, vault_role: int
    ) -> "VaultStorage":
        return SimpleNamespace(
            facade=None,
            close=lambda: None,
            archive=SimpleNamespace(
                stats=lambda: SimpleNamespace(
                    node=uuid.UUID(int=0),
                )
            )
        )

    @classmethod
    def _check_type(cls, portfolio: PrivatePortfolio, server: bool) -> None:
        return Const.A_TYPE_ADMIN_CLIENT
