#
# Copyright (c) 2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import sys
sys.path.append('../lib')  # noqa
sys.path.append('../lib')  # noqa

import pyximport # noqa E402
pyximport.install()  # noqa

import testing
import tempfile
import logging
import collections
import asyncio

from util.policy import DummyPolicy
from util.stub import Stub

from libangelos.ioc import Container, Config, StaticHandle
from libangelos.facade.facade import Facade
from libangelos.prefs import Preferences
from libangelos.const import Const


def _run(coro):
    return asyncio.get_event_loop().run_until_complete(coro)


CONFIG = {
    "prefs": {
        "network": ("Preferences", "CurrentNetwork", None),
    }
}


class Configuration(Config, Container):
    """Application configuration stub."""

    def __init__(self):
        """Initialize container and configuration."""
        Container.__init__(self, self.__config())

    def __config(self):
        return {
            "config": lambda self: collections.ChainMap(CONFIG),
            "facade": lambda self: StaticHandle(Facade),
            "prefs": lambda self: Preferences(self.facade, CONFIG["prefs"]),
        }


class App(Stub):
    """Test application class."""

    def build_config(self) -> Container:
        """Build configuration."""
        return Configuration()


class TestPreferences(testing.TestCase):
    """Testing the preferences class."""

    @classmethod
    def setUp(self):
        """Prepare before testing."""
        logging.basicConfig(stream=sys.stdout, level=logging.DEBUG)
        self.dir = tempfile.TemporaryDirectory()
        self.secret = DummyPolicy.create_person_facade(self.dir.name)
        self.app = App()
        self.app.ioc.facade = _run(Facade.open(self.dir.name, self.secret))
        _run(self.app.ioc.prefs.load())

    @classmethod
    def tearDown(self):
        """Cleanup after testing."""
        self.app.ioc.facade.archive(Const.CNL_VAULT).close()
        self.dir.cleanup()

    def test_prefs(self):
        """Creating new empty archive."""
        logging.info('====== %s ======' % 'test_prefs')
        network = "Hello, world!"
        self.app.ioc.prefs.network = network
        _run(self.app.ioc.prefs.save())
        self.assertEqual(network, self.app.ioc.prefs.network)


if __name__ == '__main__':
    testing.main(argv=['first-arg-is-ignored'])
