# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Indexing operations for client and server.
"""
import csv
import io
import logging

from .operation import Operation
from ..facade.facade import Facade
from ..worker import Worker
from ..policy import PortfolioPolicy, PGroup, DocSet, Crypto


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
        logging.info('Start indexing networks')
        portfolio = self.__facade.load_portfolio(
            self.__facade.portfolio.entity.id, PGroup.ALL)
        datalist = await self.__facade._vault.search(path='/profiles/*/*.net')
        network_list = set()

        async def validate_trust(data: bytes):
            network = PortfolioPolicy.deserialize(data)
            network_portfolio = self.__facade.load_portfolio(
                network.issuer, PGroup.ALL)

            portfolio_trusted = DocSet(
                portfolio.owner.trusted | network_portfolio.issuer.trusted)

            trusted = portfolio_trusted.get_owner(
                portfolio.entity.id).intersection(
                    portfolio_trusted.get_issuer(network_portfolio.entity.id))

            valid_trusted = False
            for trust in trusted:
                try:
                    valid = True
                    valid = trust.validate() if valid else valid
                    valid = Crypto.verify(
                        trust, network_portfolio) if valid else valid
                except Exception:
                    valid = False

                if valid:
                    valid_trusted = True

            network_trusted = DocSet(
                portfolio.issuer.trusted | network_portfolio.owner.trusted)

            trusting = network_trusted.get_owner(
                network_portfolio.entity.id).intersection(
                    network_trusted.get_issuer(portfolio.entity.id))

            valid_trusting = False
            for trust in trusting:
                try:
                    valid = True
                    valid = trust.validate() if valid else valid
                    valid = Crypto.verify(
                        trust, portfolio) if valid else valid
                except Exception:
                    valid = False

                if valid:
                    valid_trusting = True

            network_list.add(
                [network.issuer, valid_trusted and valid_trusting])

        for data in datalist:
            network_list.add(await validate_trust(data))

        csvdata = io.BytesIO()
        writer = csv.writer(csvdata)
        writer.writerows(network_list)

        self.__facade._vault.save_settings('networks.csv', csvdata)
        logging.info('Done indexing networks')
