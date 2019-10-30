# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring."""
import os

# import binascii
import collections
import json
import uuid
import logging
from typing import Callable, Awaitable

from kivy.app import App
from kivy.clock import Clock
from kivy.uix.screenmanager import ScreenManager
from kivymd.theming import ThemeManager
from kivymd.uix.snackbar import Snackbar

from libangelos.ioc import Container, ContainerAware, Config, Handle
from libangelos.worker import Worker
from libangelos.starter import Starter
from libangelos.utils import Util, Event
from libangelos.const import Const
from libangelos.archive.helper import Glue
from libangelos.policy.lock import KeyLoader
from libangelos.policy.portfolio import Portfolio, PGroup
from libangelos.operation.indexer import Indexer

# from .state import StateMachine
from libangelos.logger import LogHandler
from libangelos.ssh.ssh import SessionManager
from libangelos.ssh.client import ClientsClient
from libangelos.facade.facade import Facade
from libangelos.automatic import Automatic
from libangelos.prefs import Preferences

from .ui.root import UserScreen
from .ui.wizard import (
    SetupScreen,
    PersonSetupGuide,
    MinistrySetupGuide,
    ChurchSetupGuide,
)
from .ui.start import StartScreen

from .vars import ENV_DEFAULT, ENV_IMMUTABLE, CONFIG_DEFAULT, CONFIG_IMMUTABLE


class Configuration(Config, Container):
    def __init__(self):
        Container.__init__(self, self.__config())

    def __load(self, filename):
        try:
            with open(os.path.join(self.auto.dir.root, filename)) as jc:
                return json.load(jc.read())
        except FileNotFoundError:
            return {}

    def __config(self):
        return {
            "env": lambda self: collections.ChainMap(
                ENV_IMMUTABLE,
                vars(self.auto),
                self.__load("env.json"),
                ENV_DEFAULT,
            ),
            "config": lambda self: collections.ChainMap(
                CONFIG_IMMUTABLE, self.__load("config.json"), CONFIG_DEFAULT
            ),
            "client": lambda self: Handle(ClientsClient),
            "log": lambda self: LogHandler(self.config["logger"]),
            "session": lambda self: SessionManager(),
            "facade": lambda self: Handle(Facade),
            "auto": lambda self: Automatic("Logo"),
            "prefs": lambda self: Preferences(self.facade),
            "quit": lambda self: Event(),
        }


class LogoMessenger(ContainerAware, App):
    theme_cls = ThemeManager()

    def __init__(self):
        """Initialize app logger."""
        ContainerAware.__init__(self, Configuration())
        App.__init__(self)
        self._worker = Worker("client.secondary", self.ioc)
        self.theme_cls.primary_palette = "Green"

    def build(self):
        """"""
        self.title = "Logo"
        widget = ScreenManager(id="main_mngr")
        widget.add_widget(StartScreen(name="splash"))
        Clock.schedule_once(self.start, 3)
        return widget

    def start(self, timestamp):
        vault_file = Util.path(self.user_data_dir, Const.CNL_VAULT)

        if os.path.isfile(vault_file):
            masterkey = KeyLoader.get()
            facade = Glue.run_async(Facade.open(self.user_data_dir, masterkey))
            self.ioc.facade = facade
            self.switch("splash", UserScreen(name="user"))
            Glue.run_async(self.ioc.prefs.load())
        else:
            self.switch("splash", SetupScreen(name="setup"))

    def goto_person_setup(self):
        self.switch("setup", PersonSetupGuide(name="setup_guide"))

    def goto_ministry_setup(self):
        self.switch("setup", MinistrySetupGuide(name="setup_guide"))

    def goto_church_setup(self):
        self.switch("setup", ChurchSetupGuide(name="setup_guide"))

    def goto_user2(self):
        self.switch("setup_guide", UserScreen(name="user"))
        Glue.run_async(self.ioc.prefs.load())

    def switch(self, old, screen):
        """Switch to another main screen."""

        self.root.add_widget(screen)
        self.root.current = screen.name

        screen = self.root.get_screen(old)
        self.root.remove_widget(screen)

    async def __open_connection(self, host: Portfolio):
        return await Starter().clients_client(
            self.ioc.facade.portfolio, host, ioc=self.ioc
        )

    def check_mail(self):
        """Connect to server and start mail replication."""
        try:
            network_id = uuid.UUID(self.ioc.prefs.network)
            self.connect_network(network_id, self.__start_replication_mail)
        except ValueError:
            Snackbar(text="No network configured.").show()
            logging.warning("No network configured.")

    def __start_replication_mail(self, future: Awaitable) -> None:
        """Start replication preset for mail sync."""
        if future.done() and not future.exception():
            _, client = future.result()
            self._worker.run_coroutine(client.mail())

    def index_networks(self):
        """Start network indexing background task."""
        Glue.run_async(Indexer(self.ioc.facade, self._worker).networks_index())

    def __connection_snackbar(self, future: Awaitable) -> None:
        """Will show appropriate snackbar based on connection status."""
        if future.cancelled():
            Snackbar(text="Connection cancelled.").show()
        elif future.done():
            e = future.exception()
            if e:
                logging.error(e, exc_info=True)
                Snackbar(text="Connection failed. {0}".format(e)).show()
            else:
                Snackbar(text="Success connecting to network.").show()

    def connect_network(
        self,
        network_id: uuid.UUID,
        callback: Callable[[Awaitable], None] = None,
    ) -> Awaitable:
        """Open connection to a network."""
        host = Glue.run_async(
            self.ioc.facade.load_portfolio(
                network_id, PGroup.SHARE_MIN_COMMUNITY
            )
        )

        future = self._worker.run_coroutine(self.__open_connection(host))
        if callback:
            future.add_done_callback(callback)
        future.add_done_callback(self.__connection_snackbar)

        return future


def start():
    """Entry point for client app."""
    LogoMessenger().run()
