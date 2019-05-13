# cython: language_level=3
"""Module docstring."""
import os
import collections
import json

from kivy.app import App
from kivy.lang import Builder
from kivymd.theming import ThemeManager

from ..ioc import Container, ContainerAware, Config, Handle

from ..utils import Event

# from .state import StateMachine
from ..logger import LogHandler
from ..ssh.ssh import SessionManager
from ..facade.facade import Facade
from ..automatic import Automatic

from .ui.root import MAIN
from .vars import (
    ENV_DEFAULT, ENV_IMMUTABLE, CONFIG_DEFAULT, CONFIG_IMMUTABLE)


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
            'env': lambda self: collections.ChainMap(
                ENV_IMMUTABLE,
                vars(self.auto),
                self.__load('env.json'),
                ENV_DEFAULT),
            'config': lambda self: collections.ChainMap(
                CONFIG_IMMUTABLE,
                self.__load('config.json'),
                CONFIG_DEFAULT),
            # 'state': lambda self: StateMachine(self.config['state']),
            'log': lambda self: LogHandler(self.config['logger']),
            'session': lambda self: SessionManager(),
            'facade': lambda self: Handle(Facade),
            'auto': lambda self: Automatic(self.opts),
            'quit': lambda self: Event(),
        }


class Client(ContainerAware, App):
    theme_cls = ThemeManager()

    def __init__(self):
        """Initialize app logger."""
        ContainerAware.__init__(self, Configuration())
        App.__init__(self)
        self.theme_cls.primary_palette = 'Green'

    def build(self):
        return Builder.load_string(MAIN)


def start():
    """Entry point for client app."""
    Client().run()
