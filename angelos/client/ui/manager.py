from kivy.clock import Clock
from kivy.uix.screenmanager import ScreenManager, Screen
from ...const import Const
from ...utils import Util

from .default import DefaultNavigation
from .setup import Setup
from .spinner import Spinner


class InterfaceManager(ScreenManager):
    def __init__(self, configured, **kwargs):
        Util.is_type(configured, bool)

        self.id = 'main'
        ScreenManager.__init__(self, **kwargs)

        if configured:
            self.show_default()
        else:
            self.show_setup()

    def change(self, screen):
        old = self.current
        self.add_widget(screen)
        self.current = screen.name

        if self.has_screen(old):
            Clock.schedule_once(
                 lambda dt: self.remove_widget(self.get_screen(old)), 1.05)

    def show_splash(self):
        self.change(Screen(name=Const.I_SPLASH))

    def show_default(self):
        self.change(DefaultNavigation(name=Const.I_DEFAULT))

    def show_spinner(self):
        self.change(Spinner(name=Const.I_SPINNER))

    def show_setup(self):
        self.change(Setup(name=Const.I_SETUP))
