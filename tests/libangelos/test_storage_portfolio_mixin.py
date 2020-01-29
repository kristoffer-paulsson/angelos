import collections
import copy
import logging
import math
import uuid
from tempfile import TemporaryDirectory

from libangelos.archive.portfolio_mixin import PortfolioMixin
from libangelos.error import PortfolioAlreadyExists, PortfolioExistsNot, PortfolioIllegalDelete
from libangelos.operation.setup import SetupPersonOperation
from libangelos.policy.portfolio import PGroup, Portfolio, DOCUMENT_PATH, PortfolioPolicy, PrivatePortfolio, DocSet
from libangelos.policy.verify import StatementPolicy

from dummy.support import run_async, StubMaker, Generate, Operations
from dummy.testing import BaseTestNetwork


class TestPortfolioMixin(BaseTestNetwork):
    pref_loglevel = logging.INFO
    pref_count = 2

    facade = None
    portfolios = list()
    portfolio = None

    @run_async
    async def setUp(self) -> None:
        self.dir = TemporaryDirectory()
        self.facade = await StubMaker.create_person_facace(self.dir.name, Generate.new_secret())
        self.portfolio = SetupPersonOperation.create(Generate.person_data()[0])
        await Operations.portfolios(self.pref_count, self.portfolios)

    def tearDown(self) -> None:
        self.dir.cleanup()
        self.portfolios = list()
        self.portfolio = None
        del self.facade

    def mutual_trust_and_verification(self):
        """Make the facade mutually trusted and verified with all portfolios"""
        for portfolio in self.portfolios:
            StatementPolicy.verified(self.portfolio, portfolio)
            StatementPolicy.verified(portfolio, self.portfolio)
            StatementPolicy.trusted(self.portfolio, portfolio)
            StatementPolicy.trusted(portfolio, self.portfolio)

    async def get_storage_portfolio_file_list(self, storage: PortfolioMixin, eid: uuid.UUID) -> set:
        """Create a set of all files in a portfolio stored in a storage"""
        dirname = storage.portfolio_path(eid)
        return await storage.archive.glob(name="{dir}/*".format(dir=dirname))

    def get_portfolio_file_list(self, storage: PortfolioMixin, portfolio: Portfolio):
        """Create a set of all filenames from a portfolio"""
        dirname = storage.portfolio_path(portfolio.entity.id)
        issuer, owner = portfolio.to_sets()
        return {DOCUMENT_PATH[doc.type].format(dir=dirname, file=doc.id) for doc in issuer | owner}

    async def load_storage_file_list(self, storage: PortfolioMixin, file_list: set) -> set:
        """Load all files from a storage expecting them to be Documents and exist."""
        files = set()
        for filename in file_list:
            data = await storage.archive.load(filename)
            doc = PortfolioPolicy.deserialize(data)
            files.add(doc)

        return files

    def test_update_portfolio(self):
        try:
            raise NotImplementedError()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_add_portfolio(self):
        try:
            # Strange error where documents are removed from RAM!
            self.mutual_trust_and_verification()

            files_loaded = self.get_portfolio_file_list(self.facade.storage.vault, self.portfolio)
            print(self.portfolio, "="*80)
            success, rejected, removed = await self.facade.storage.vault.add_portfolio(self.portfolio)
            files_saved = await self.get_storage_portfolio_file_list(
                self.facade.storage.vault, self.portfolio.entity.id)

            docset = DocSet(await self.load_storage_file_list(self.facade.storage.vault, files_saved))
            portfolio = PrivatePortfolio.factory(
                docset.get_issuer(self.portfolio.entity.id),
                docset.get_owner(self.portfolio.entity.id)
            )

            issuer, owner = self.portfolio.to_sets()
            loaded = issuer | owner

            issuer, owner = portfolio.to_sets()
            saved = issuer | owner

            print(files_loaded - files_saved)
            print(self.portfolio, "="*80, portfolio)


            print(loaded, "\n", saved)

            print(success, rejected, removed)
        except Exception as e:
            self.fail(e)

    def test_docs_to_portfolio(self):
        try:
            raise NotImplementedError()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_list_portfolios(self):
        try:
            allids = set()
            for portfolio in self.portfolios:
                allids.add(portfolio.entity.id)
            allids.add(self.portfolio.entity.id)
            allids.add(self.facade.data.portfolio.entity.id)

            for portfolio in self.portfolios:
                self.assertTrue(await self.facade.storage.vault.import_portfolio(portfolio))
            self.assertTrue(await self.facade.storage.vault.import_portfolio(self.portfolio))
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
            self.assertTrue(await self.facade.storage.vault.import_portfolio(self.portfolio))
            files = self.get_portfolio_file_list(self.facade.storage.vault, self.portfolio)

            portfolio = PrivatePortfolio.factory(
                await self.load_storage_file_list(self.facade.storage.vault, files))
            self.assertEqual(portfolio, self.portfolio)

            with self.assertRaises(PortfolioAlreadyExists):
                await self.facade.storage.vault.import_portfolio(self.portfolio)

        except Exception as e:
            self.fail(e)

    def test_load_portfolio(self):
        try:
            raise NotImplementedError()
        except Exception as e:
            self.fail(e)

    def test_reload_portfolio(self):
        try:
            raise NotImplementedError()
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_save_portfolio(self):
        try:
            with self.assertRaises(PortfolioExistsNot):
                await self.facade.storage.vault.save_portfolio(self.portfolio)

            self.assertTrue(await self.facade.storage.vault.import_portfolio(self.portfolio))
            self.mutual_trust_and_verification()
            await self.facade.storage.vault.save_portfolio(self.portfolio)

            files_loaded = self.get_portfolio_file_list(self.facade.storage.vault, self.portfolio)
            files_saved = await self.get_storage_portfolio_file_list(
                self.facade.storage.vault, self.portfolio.entity.id)

            self.assertEqual(collections.Counter(files_loaded), collections.Counter(files_saved))

            docset = DocSet(await self.load_storage_file_list(self.facade.storage.vault, files_saved))
            portfolio = PrivatePortfolio.factory(
                docset.get_issuer(self.portfolio.entity.id),
                docset.get_owner(self.portfolio.entity.id)
            )
            self.assertEqual(portfolio, self.portfolio)
        except Exception as e:
            self.fail(e)

    @run_async
    async def test_delete_portfolio(self):
        try:
            with self.assertRaises(PortfolioExistsNot):
                await self.facade.storage.vault.delete_portfolio(self.portfolio.entity.id)

            self.mutual_trust_and_verification()
            self.assertTrue(await self.facade.storage.vault.import_portfolio(self.portfolio))

            files_saved = await self.get_storage_portfolio_file_list(
                self.facade.storage.vault, self.portfolio.entity.id)

            with self.assertRaises(PortfolioIllegalDelete):
                await self.facade.storage.vault.delete_portfolio(self.facade.data.portfolio.entity.id)

            self.assertTrue(await self.facade.storage.vault.delete_portfolio(self.portfolio.entity.id))

            files_deleted = await self.get_storage_portfolio_file_list(
                self.facade.storage.vault, self.portfolio.entity.id)
            self.assertNotEqual(files_saved, files_deleted)
            self.assertEqual(files_deleted, set())
        except Exception as e:
            self.fail(e)
