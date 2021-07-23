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

from angelos.common.misc import Misc
from angelos.document.utils import Helper as DocumentHelper
from angelos.facade.facade import TaskFacadeExtension
from angelos.portfolio.statement.validate import ValidateTrustedStatement
from angelos.portfolio.utils import Groups, Fields, Definitions as PortfolioDefinitions


class NetworkIndexerTask(TaskFacadeExtension):
    """Task extension that runs as a background job in the facade."""

    ATTRIBUTE = ("network_index",)
    INVOKABLE = (True,)

    __network_list = None

    async def _run(self) -> None:
        vault = self.facade.storage.vault
        portfolio = await vault.load_portfolio(self.facade.data.portfolio.entity.id, Groups.ALL)
        suffix = PortfolioDefinitions.SUFFIXES[Fields.NET]
        pattern = str(vault.PATH_PORTFOLIOS[0].joinpath("/*/*" + suffix))
        files = await vault.search(pattern)
        validator = ValidateTrustedStatement()

        networks = set()
        for filename in files.values():
            network = DocumentHelper.deserialize(await vault.archive.load(filename))
            foreign = await vault.load_portfolio(network.issuer, Groups.ALL)

            if any([
                validator.validate(foreign, doc) for doc in portfolio.get_issuer(
                    portfolio.get_not_expired(portfolio.trusted_owner), foreign.entity.id)
            ]) and any([
                validator.validate(portfolio, doc) for doc in foreign.get_issuer(
                    foreign.get_not_expired(foreign.trusted_owner), portfolio.entity.id)
            ]):
                networks.add((network.issuer, True))
            else:
                networks.add((network.issuer, False))
            await Misc.sleep()

        csv_data = io.StringIO()
        writer = csv.writer(csv_data)
        writer.writerows(networks)
        await vault.save_settings("networks.csv", csv_data)
