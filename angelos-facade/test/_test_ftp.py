import logging
import os
import sys
import tracemalloc
from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from angelos.document.types import ChurchData
from angelos.facade.facade import Facade
from angelos.facade.storage.ftp import FtpStorage
from angelos.lib.const import Const
from angelos.meta.fake import Generate
from angelos.portfolio.portfolio.setup import SetupChurchPortfolio


class TestFtpStorage(TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        logging.basicConfig(stream=sys.stderr, level=logging.DEBUG)
        tracemalloc.start()

    def setUp(self) -> None:
        self.secret = os.urandom(32)
        self.dir = TemporaryDirectory()
        self.home = Path(self.dir.name)
        self.facade = Facade(self.home, self.secret,
            SetupChurchPortfolio().perform(ChurchData(**Generate.church_data()[0])),
            role=Const.A_ROLE_PRIMARY, server=True
        )

    def tearDown(self) -> None:
        self.facade.close()
        self.dir.cleanup()

    def test_run(self):
        self.assertIsInstance(self.facade.storage.ftp, FtpStorage)
