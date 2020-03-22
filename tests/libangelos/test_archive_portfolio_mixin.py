import collections
import copy

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

    @run_async
    async def test_update_portfolio(self):
        # TODO: Make sure it follows policy
        # update_portfolio don't seem to work according to the same rules as add_portfolio
        try:
            local_portfolio = self.portfolios[0]
            await self.facade.storage.vault.add_portfolio(local_portfolio)
            files_saved_original = await Introspection.get_storage_portfolio_file_list(
                self.facade.storage.vault, local_portfolio.entity.id)
            files_memory_original = Introspection.get_portfolio_file_list(
                self.facade.storage.vault, local_portfolio)
            self.assertEqual(files_saved_original, files_memory_original)

            self.mutual_trust_and_verification()

            files_memory_mutual = Introspection.get_portfolio_file_list(
                self.facade.storage.vault, local_portfolio)
            self.assertEqual(files_saved_original, files_memory_original)

            success, rejected, removed = await self.facade.storage.vault.update_portfolio(local_portfolio)
            files_updated_removed = Introspection.get_portfolio_virtual_list(
                self.facade.storage.vault, local_portfolio, removed)

            files_saved_mutual = await Introspection.get_storage_portfolio_file_list(
                self.facade.storage.vault, local_portfolio.entity.id)

            self.assertEqual(files_saved_mutual, files_memory_mutual)

            print("files_saved_original:", files_saved_original)
            print("files_memory_original:", files_memory_original)

            print("files_saved_mutual:", files_saved_mutual)
            print("files_memory_mutual:", files_memory_mutual)

            print("files_updated_removed:", files_updated_removed)


            """
            # Files updated, files saved from updated portfolio
            files_updated = await Introspection.get_storage_portfolio_file_list(
                self.facade.storage.vault, local_portfolio.entity.id)

            loaded_portfolio = await self.facade.storage.vault.load_portfolio(
                local_portfolio.entity.id, PGroup.ALL)

            # Files loaded, files from loaded updated portfolio
            files_loaded = Introspection.get_portfolio_file_list(self.facade.storage.vault, loaded_portfolio)
            print(files_loaded)
            print(files_updated)
            self.assertEqual(files_updated - files_missing, files_loaded)

            print(files_loaded)
            print(files_updated)
            print(files_missing)

            print(files_updated - files_saved - files_missing)
            print(files_loaded - files_saved - files_missing)
            self.assertEqual(files_updated - files_saved - files_missing, files_loaded - files_saved - files_missing)
            self.assertEqual(files_updated, files_loaded)

            docset = DocSet(await Introspection.load_storage_file_list(
                self.facade.storage.vault, files_updated | files_missing))

            composite_portfolio = PrivatePortfolio.factory(
                docset.get_issuer(local_portfolio.entity.id),
                docset.get_owner(local_portfolio.entity.id)
            )

            self.assertNotEqual(local_portfolio, loaded_portfolio)
            self.assertEqual(local_portfolio, composite_portfolio)
            """

        except Exception as e:
            self.fail(e)

    @run_async
    async def test_add_portfolio(self):
        # TODO: Make sure it follows policy
        try:
            local_portfolio = self.portfolios[0]
            self.mutual_trust_and_verification()

            files_loaded = Introspection.get_portfolio_file_list(self.facade.storage.vault, local_portfolio)

            success, rejected, removed = await self.facade.storage.vault.add_portfolio(local_portfolio)
            files_missing = Introspection.get_portfolio_virtual_list(
                self.facade.storage.vault, local_portfolio, removed)

            files_saved = await Introspection.get_storage_portfolio_file_list(
                self.facade.storage.vault, local_portfolio.entity.id)

            self.assertEqual(files_loaded, files_saved | files_missing)

            docset = DocSet(await Introspection.load_storage_file_list(self.facade.storage.vault, files_saved))
            docset2 = copy.deepcopy(docset)
            loaded_portfolio = PrivatePortfolio.factory(
                docset.get_issuer(local_portfolio.entity.id),
                docset.get_owner(local_portfolio.entity.id)
            )
            composite_portfolio = PrivatePortfolio.factory(
                docset2.get_issuer(local_portfolio.entity.id),
                docset2.get_owner(local_portfolio.entity.id) | removed
            )

            self.assertNotEqual(local_portfolio, loaded_portfolio)
            self.assertEqual(local_portfolio, composite_portfolio)

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


