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
"""Random dummy data generators."""
import uuid

from libangelos.policy.portfolio import Portfolio, DOCUMENT_PATH, PortfolioPolicy
#from libangelos.storage.portfolio_mixin import PortfolioMixin


class Introspection:
    """Facade introspection tools."""

    @staticmethod
    async def get_storage_portfolio_file_list(storage: "PortfolioMixin", eid: uuid.UUID) -> set:
        """Create a set of all files in a portfolio stored in a storage"""
        dirname = storage.portfolio_path(eid)
        return await storage.archive.glob(name="{dir}/*".format(dir=dirname))

    @staticmethod
    def get_portfolio_file_list(storage: "PortfolioMixin", portfolio: Portfolio):
        """Create a set of all filenames from a portfolio"""
        dirname = storage.portfolio_path(portfolio.entity.id)
        issuer, owner = portfolio.to_sets()
        return {DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id) for doc in issuer | owner}

    @staticmethod
    def get_portfolio_virtual_list(storage: "PortfolioMixin", portfolio: Portfolio, docs: set):
        """Create a set of virtual filenames from a portfolio"""
        dirname = storage.portfolio_path(portfolio.entity.id)
        return {DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id) for doc in docs}

    @staticmethod
    async def load_storage_file_list(storage: "PortfolioMixin", file_list: set) -> set:
        """Load all files from a storage expecting them to be Documents and exist."""
        files = set()
        for filename in file_list:
            data = await storage.archive.load(filename)
            doc = PortfolioPolicy.deserialize(data)
            files.add(doc)

        return files