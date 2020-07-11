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
import collections
import copy
import uuid

from libangelos.error import PortfolioAlreadyExists, PortfolioExistsNot, PortfolioIllegalDelete
from libangelos.policy.portfolio import PrivatePortfolio, DocSet, PGroup, Portfolio
from libangelos.policy.verify import StatementPolicy

from angelossim.support import run_async, Introspection
from angelossim.testing import BaseTestFacade


class TestPortfolioMixin(BaseTestFacade):
    count = 6
    provision = False

    def mutual_trust_and_verification(self):
        """Make the facade mutually trusted and verified with all portfolios"""
        for portfolio in self.portfolios:
            StatementPolicy.verified(self.portfolio, portfolio)
            StatementPolicy.verified(portfolio, self.portfolio)
            StatementPolicy.trusted(self.portfolio, portfolio)
            StatementPolicy.trusted(portfolio, self.portfolio)

    async def load(self, eid: uuid.UUID):
        """Load portfolio by using custom loader."""
        docset = DocSet(
            await Introspection.load_storage_file_list(
                self.facade.storage.vault,
                await Introspection.get_storage_portfolio_file_list(
                    self.facade.storage.vault,
                    eid
                )
            )
        )

        return PrivatePortfolio.factory(
            docset.get_issuer(eid),
            docset.get_owner(eid)
        )

    @run_async
    async def test_update_portfolio(self):
        # TODO: Make sure it follows policy
        # update_portfolio don't seem to work according to the same rules as add_portfolio
        try:
            local_portfolio = self.portfolios[0]
            original_portfolio = copy.deepcopy(local_portfolio)
            # Add the local portfolio
            await self.facade.storage.vault.add_portfolio(local_portfolio)

            # Make a copy and remove docs according to specified behavior
            temp_portfolio = copy.deepcopy(local_portfolio)
            temp_portfolio.owner.revoked = set()
            temp_portfolio.owner.trusted = set()
            temp_portfolio.owner.verified = set()

            # Compare copy and loaded portfolio
            self.assertEqual(temp_portfolio, await self.load(temp_portfolio.entity.id))

            # Add some docs according to user behavior
            self.mutual_trust_and_verification()

            # Compare local and original, should be different
            self.assertNotEqual(local_portfolio, original_portfolio)

            # Update local portfolio, the "user" modified
            await self.facade.storage.vault.update_portfolio(local_portfolio)

            # Make a new copy and remove according to defined behavior
            temp_portfolio = copy.deepcopy(local_portfolio)
            temp_portfolio.owner.revoked = set()
            temp_portfolio.owner.trusted = set()
            temp_portfolio.owner.verified = set()

            # Compare current local and loaded/updated files
            self.assertEqual(temp_portfolio, await self.load(temp_portfolio.entity.id))

        except Exception as e:
            self.fail(e)

    @run_async
    async def test_add_portfolio(self):
        try:
            local_portfolio = self.portfolios[0]
            self.mutual_trust_and_verification()

            success, _, _ = await self.facade.storage.vault.add_portfolio(local_portfolio)
            self.assertTrue(success)

            loaded_portfolio = await self.load(local_portfolio.entity.id)

            self.assertNotEqual(local_portfolio, loaded_portfolio)

            local_portfolio.owner.revoked = set()
            local_portfolio.owner.trusted = set()
            local_portfolio.owner.verified = set()

            self.assertEqual(local_portfolio, loaded_portfolio)

        except Exception as e:
            self.fail(e)

    def test_docs_to_portfolio(self):
        try:
            # raise NotImplementedError()
            pass
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_list_portfolios(self):
        try:
            allids = set()
            for portfolio in self.portfolios:
                allids.add(portfolio.entity.id)
            allids.add(self.facade.data.portfolio.entity.id)

            for portfolio in self.portfolios:
                self.assertTrue(await self.facade.storage.vault.import_portfolio(portfolio))
            self.assertEqual(
                collections.Counter(await self.facade.storage.vault.list_portfolios()),
                collections.Counter(allids)
            )
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_import_portfolio(self):
        """Full portfolio import"""
        try:
            local_portfolio = self.portfolios[0]
            self.assertTrue(await self.facade.storage.vault.import_portfolio(local_portfolio))
            files = Introspection.get_portfolio_file_list(self.facade.storage.vault, local_portfolio)

            portfolio = PrivatePortfolio.factory(
                await Introspection.load_storage_file_list(self.facade.storage.vault, files), set())
            self.assertEqual(portfolio, local_portfolio)

            with self.assertRaises(PortfolioAlreadyExists):
                await self.facade.storage.vault.import_portfolio(local_portfolio)

        except Exception as e:
            self.fail(e)

    @run_async
    async def test_load_portfolio(self):
        try:
            local_portfolio = self.portfolios[0]
            with self.assertRaises(PortfolioExistsNot):
                await self.facade.storage.vault.load_portfolio(local_portfolio.entity.id, PGroup.ALL)

            await self.facade.storage.vault.import_portfolio(local_portfolio)
            loaded_portfolio = await self.facade.storage.vault.load_portfolio(
                local_portfolio.entity.id, PGroup.ALL)
            self.assertEqual(local_portfolio, loaded_portfolio)
            self.assertIsInstance(loaded_portfolio, PrivatePortfolio)
            loaded_portfolio = await self.facade.storage.vault.load_portfolio(
                local_portfolio.entity.id, PGroup.VERIFIER)
            self.assertIsInstance(loaded_portfolio, Portfolio)

            local_portfolio = self.portfolios[1].to_portfolio()
            await self.facade.storage.vault.import_portfolio(local_portfolio)
            loaded_portfolio = await self.facade.storage.vault.load_portfolio(
                local_portfolio.entity.id, PGroup.ALL)
            self.assertEqual(local_portfolio, loaded_portfolio)
            self.assertIsInstance(loaded_portfolio, Portfolio)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_reload_portfolio(self):
        try:
            local_portfolio = self.portfolios[0]
            with self.assertRaises(PortfolioExistsNot):
                await self.facade.storage.vault.reload_portfolio(local_portfolio, PGroup.ALL)

            await self.facade.storage.vault.add_portfolio(local_portfolio)

            early_portfolio = copy.deepcopy(local_portfolio)
            self.assertEqual(local_portfolio, early_portfolio)
            self.mutual_trust_and_verification()
            self.assertNotEqual(local_portfolio, early_portfolio)

            await self.facade.storage.vault.update_portfolio(local_portfolio)
            await self.facade.storage.vault.reload_portfolio(early_portfolio, PGroup.ALL)
            self.assertNotEqual(local_portfolio, early_portfolio)

            self.assertEqual(
                collections.Counter(early_portfolio.owner.verified),
                collections.Counter(local_portfolio.owner.verified)
            )
            self.assertEqual(
                collections.Counter(early_portfolio.owner.trusted),
                collections.Counter(local_portfolio.owner.trusted)
            )

            self.assertNotEqual(
                collections.Counter(early_portfolio.issuer.verified),
                collections.Counter(local_portfolio.issuer.verified)
            )
            self.assertNotEqual(
                collections.Counter(early_portfolio.issuer.trusted),
                collections.Counter(local_portfolio.issuer.trusted)
            )
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_save_portfolio(self):
        try:
            local_portfolio = self.portfolios[0]
            with self.assertRaises(PortfolioExistsNot):
                await self.facade.storage.vault.save_portfolio(local_portfolio)

            self.assertTrue(await self.facade.storage.vault.import_portfolio(local_portfolio))
            self.mutual_trust_and_verification()
            await self.facade.storage.vault.save_portfolio(local_portfolio)

            files_loaded = Introspection.get_portfolio_file_list(self.facade.storage.vault, local_portfolio)
            files_saved = await Introspection.get_storage_portfolio_file_list(
                self.facade.storage.vault, local_portfolio.entity.id)

            self.assertEqual(collections.Counter(files_loaded), collections.Counter(files_saved))

            docset = DocSet(await Introspection.load_storage_file_list(self.facade.storage.vault, files_saved))
            portfolio = PrivatePortfolio.factory(
                docset.get_issuer(local_portfolio.entity.id),
                docset.get_owner(local_portfolio.entity.id)
            )
            self.assertEqual(portfolio, local_portfolio)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_delete_portfolio(self):
        try:
            local_portfolio = self.portfolios[0]
            with self.assertRaises(PortfolioExistsNot):
                await self.facade.storage.vault.delete_portfolio(local_portfolio.entity.id)

            self.mutual_trust_and_verification()
            self.assertTrue(await self.facade.storage.vault.import_portfolio(local_portfolio))

            files_saved = await Introspection.get_storage_portfolio_file_list(
                self.facade.storage.vault, local_portfolio.entity.id)

            with self.assertRaises(PortfolioIllegalDelete):
                await self.facade.storage.vault.delete_portfolio(self.facade.data.portfolio.entity.id)

            self.assertTrue(await self.facade.storage.vault.delete_portfolio(local_portfolio.entity.id))

            files_deleted = await Introspection.get_storage_portfolio_file_list(
                self.facade.storage.vault, local_portfolio.entity.id)
            self.assertNotEqual(files_saved, files_deleted)
            self.assertEqual(files_deleted, set())
        except Exception as e:
            self.fail(e)


