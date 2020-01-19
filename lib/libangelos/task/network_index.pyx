# cython: language_level=3
#
# Copyright (c) 2018-2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""A task for indexing networks in relation to portfolios."""
import csv
import io
import uuid

from libangelos.archive.portfolio_mixin import DOCUMENT_PATH
from libangelos.document.document import DocType
from libangelos.policy.crypto import Crypto
from libangelos.policy.portfolio import PGroup, PortfolioPolicy, PrivatePortfolio
from libangelos.task.task import TaskFacadeExtension


class NetworkIndexerTask(TaskFacadeExtension):
    """Task extension that runs as a background job in the facade."""

    ATTRIBUTE = ("network_index",)

    INVOKABLE = (True,)

    __network_list = None

    async def __validate_trust(self, nid: uuid.UUID, portfolio: PrivatePortfolio):
        vault = self.facade.storage.vault
        filename = DOCUMENT_PATH[DocType.NET_NETWORK].format(dir="/portfolios", file=str(nid))
        network = PortfolioPolicy.deserialize(vault.archive.load(filename))
        network_portfolio = await self.facade.storage.vault.load_portfolio(
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
                    try:
                        valid = True
                        valid = trusted.validate() if valid else valid
                        valid = (
                            Crypto.verify(trusted, network_portfolio)
                            if valid
                            else valid
                        )
                    except Exception:
                        valid = False

                    if valid:
                        valid_trusted = True
                if (
                        trusted.issuer == portfolio.entity.id
                ) and trusted.owner == network_portfolio.entity.id:
                    try:
                        valid = True
                        valid = trusted.validate() if valid else valid
                        valid = (
                            Crypto.verify(trusted, portfolio)
                            if valid
                            else valid
                        )
                    except Exception:
                        valid = False

                    if valid:
                        valid_trusting = True

            self.__network_list.add(
                (network.issuer, valid_trusted and valid_trusting)
            )

    async def _run(self) -> None:
        vault = self.facade.storage.vault
        portfolio = await vault.load_portfolio(self.facade.data.portfolio.entity.id, PGroup.ALL)
        pattern = DOCUMENT_PATH[DocType.NET_NETWORK].format(dir="/portfolios", file="*")
        networks = (await vault.search(pattern)).keys()

        self.__network_list = set()
        for network in networks:
            await self.__validate_trust(network, portfolio)

        csv_data = io.StringIO()
        writer = csv.writer(csv_data)
        writer.writerows(self.__network_list)
        self.__network_list = None

        await vault.save_settings("networks.csv", csv_data.getvalue().encode())
