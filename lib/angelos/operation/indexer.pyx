# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Indexing operations for client and server."""
import csv
import io
import logging

from .operation import Operation
from ..facade.facade import Facade
from ..worker import Worker
from ..policy.portfolio import PortfolioPolicy, PGroup
from ..policy.crypto import Crypto


_networks_run = False


class Indexer(Operation):
    """Indexing operations."""

    def __init__(self, facade: Facade, worker: Worker):
        """Init indexer class with worker and facade."""
        self.__facade = facade
        self.__worker = worker

    async def contacts_all_index(self):
        """Index all contacts from portfolios."""
        pass

    async def networks_index(self):
        """
        Index all networks from portfolios.

        Will find all portfolios with networks. Then tries to find which ones
        are mutually trusting.
        """
        global _networks_run
        if _networks_run:
            logging.info("Networks indexing already running.")
            return
        else:
            _networks_run = True

        logging.info("Start indexing networks")
        portfolio = await self.__facade.load_portfolio(
            self.__facade.portfolio.entity.id, PGroup.ALL
        )
        datalist = await self.__facade._vault.search(
            path="/portfolios/*/*.net", limit=200
        )
        network_list = set()

        async def validate_trust(data: bytes):
            network = PortfolioPolicy.deserialize(data)
            network_portfolio = await self.__facade.load_portfolio(
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
                network_list.add((network.issuer, False))
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

                network_list.add(
                    (network.issuer, valid_trusted and valid_trusting)
                )

        for data in datalist:
            await validate_trust(data)

        csvdata = io.StringIO()
        writer = csv.writer(csvdata)
        writer.writerows(network_list)

        await self.__facade._vault.save_settings(
            "networks.csv", csvdata.getvalue().encode()
        )
        logging.info("Done indexing networks")
        _networks_run = False
