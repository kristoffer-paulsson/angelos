import logging
import os
import sys
import tracemalloc
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.document.types import PersonData
from angelos.facade.facade import Facade
from angelos.lib.const import Const
from angelos.meta.fake import Generate
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio


class TestRoutingStorage(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = Path(self.dir.name)
        self.facade = Facade(self.home, self.secret,
            SetupPersonPortfolio().perform(PersonData(**Generate.person_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=False
        )

    def tearDown(self) -> None:
        self.facade.close()
        self.dir.cleanup()
