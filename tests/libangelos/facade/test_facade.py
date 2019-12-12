import os
import asyncio
import tracemalloc

from pprint import pprint
from unittest import TestCase
from tempfile import TemporaryDirectory

from libangelos.const import Const
from libangelos.facade.facade import Facade

from libangelos.operation.setup import SetupChurchOperation, SetupPersonOperation, SetupMinistryOperation

from dummy.support import Generate


class TestFacade(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = self.dir.name
        self.server = True

    def _portfolio(self):
        return SetupPersonOperation.create(Generate.person_data()[0], server=self.server)

    def _setup(self, portfolio):
        return asyncio.run(Facade.setup(
                self.home, self.secret,
                Const.A_ROLE_PRIMARY, self.server, portfolio=portfolio
            ))

    def _open(self):
        return asyncio.run(Facade.open(self.home, self.secret))

    def tearDown(self) -> None:
        self.dir.cleanup()

    def test_setup(self):
        try:
            portfolio = self._portfolio()
            facade = self._setup(portfolio)
            pprint(facade.data.portfolio.entity.export_yaml())
            facade.close()
        except Exception as e:
            self.fail(e)

    def test_open(self):
        try:
            portfolio = self._portfolio()
            facade = self._setup(portfolio)
            facade.close()

            facade = self._open()
            facade.close()
        except Exception as e:
            self.fail(e)
