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
"""A task for indexing networks in relation to portfolios."""
import csv
import io
from pathlib import PurePosixPath

from angelos.lib.storage.portfolio_mixin import DOCUMENT_PATH
from angelos.document.document import DocType
from angelos.lib.policy.crypto import Crypto
from angelos.lib.policy.portfolio import PGroup, PortfolioPolicy, PrivatePortfolio
from angelos.lib.task.task import TaskFacadeExtension


class NetworkIndexerTask(TaskFacadeExtension):
    """Task extension that runs as a background job in the facade."""

    ATTRIBUTE = ("network_index",)

    INVOKABLE = (True,)

    __network_list = None

    async def __validate_trust(self, filename: PurePosixPath, portfolio: PrivatePortfolio):
        vault = self.facade.storage.vault
        network = PortfolioPolicy.deserialize(await vault.archive.load(filename))
        network_portfolio = await vault.load_portfolio(
            network.issuer, PGroup.ALL
        )

        valid_trusted = False
        valid_trusting = False

        trusted_docs = (
                portfolio.owner.trusted
                | network_portfolio.issuer.trusted
                | portfolio.issuer.trusted
                | network_portfolio.owner.trusted
        )

        if len(trusted_docs) == 0:
            self.__network_list.add((network.issuer, False))
        else:
            for trusted in trusted_docs:
                if (trusted.owner == portfolio.entity.id) and (
                        trusted.issuer == network_portfolio.entity.id
                ):
                    valid = True
                    valid = trusted.validate() if valid else valid
                    valid = (
                        Crypto.verify(trusted, network_portfolio)
                        if valid
                        else valid
                    )

                    if valid:
                        valid_trusted = True
                if (
                        trusted.issuer == portfolio.entity.id
                ) and trusted.owner == network_portfolio.entity.id:
                    valid = True
                    valid = trusted.validate() if valid else valid
                    valid = (
                        Crypto.verify(trusted, portfolio)
                        if valid
                        else valid
                    )

                    if valid:
                        valid_trusting = True

            self.__network_list.add(
                (network.issuer, valid_trusted and valid_trusting)
            )

    async def _run(self) -> None:
        vault = self.facade.storage.vault
        portfolio = await vault.load_portfolio(self.facade.data.portfolio.entity.id, PGroup.ALL)
        pattern = DOCUMENT_PATH[DocType.NET_NETWORK].format(dir="/portfolios/*", file="*")
        networks = await vault.search(pattern)

        self.__network_list = set()
        for network in networks.items():
            await self.__validate_trust(network[1], portfolio)

        csv_data = io.StringIO()
        writer = csv.writer(csv_data)
        writer.writerows(self.__network_list)
        self.__network_list = None

        await vault.save_settings("networks.csv", csv_data)
