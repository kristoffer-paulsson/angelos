# cython: language_level=3
"""Module docstring."""
import os
import collections
import json

from kivy.app import App
from kivy.clock import Clock
from kivy.uix.screenmanager import ScreenManager
from kivymd.theming import ThemeManager

from ..ioc import Container, ContainerAware, Config, Handle
from ..utils import Util, Event
from ..const import Const

# from .state import StateMachine
from ..logger import LogHandler
from ..ssh.ssh import SessionManager
from ..facade.facade import Facade
from ..automatic import Automatic

from .ui.root import UserScreen
from .ui.wizard import (
    SetupScreen, PersonSetupGuide, MinistrySetupGuide, ChurchSetupGuide)
from .ui.start import StartScreen

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
            'auto': lambda self: Automatic('Logo'),
            'quit': lambda self: Event(),
        }


"""
class MainInterface(ScreenManager):
    def __init__(self):
        ScreenManager.__init__(self)
"""


class LogoMessenger(ContainerAware, App):
    theme_cls = ThemeManager()

    def __init__(self):
        """Initialize app logger."""
        ContainerAware.__init__(self, Configuration())
        App.__init__(self)
        self.theme_cls.primary_palette = 'Green'

    def build(self):
        self.title = 'Logo'
        widget = ScreenManager(id='main_mngr')
        widget.add_widget(StartScreen(name='splash'))
        Clock.schedule_once(self.start, 3)
        return widget

    def start(self, timestamp):
        vault_file = Util.path(self.user_data_dir, Const.CNL_VAULT)

        if os.path.isfile(vault_file):
            self.switch('splash', UserScreen(name='user'))
        else:
            self.switch('splash', SetupScreen(name='setup'))

    def goto_person_setup(self):
        self.switch('setup', PersonSetupGuide(name='setup_guide'))

    def goto_ministry_setup(self):
        self.switch('setup', MinistrySetupGuide(name='setup_guide'))

    def goto_church_setup(self):
        self.switch('setup', ChurchSetupGuide(name='setup_guide'))

    def goto_user2(self):
        self.switch('setup_guide', UserScreen(name='user'))

    def switch(self, old, screen):
        """Switch to another main screen."""

        self.root.add_widget(screen)
        self.root.current = screen.name

        screen = self.root.get_screen(old)
        self.root.remove_widget(screen)


def start():
    """Entry point for client app."""
    LogoMessenger().run()
