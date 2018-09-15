"""Docstring"""
import threading
import logging
from kivy.app import App
from kivy.lang import Builder
from kivymd.theming import ThemeManager

from ..const import Const
from ..worker import Worker

from .ui import UI


class LogoApp(App):
    theme_cls = ThemeManager()
    title = "Logo"

    def build(self):
        main_widget = Builder.load_string(UI)
        # self.theme_cls.theme_style = 'Dark'
        return main_widget

    def on_pause(self):
        return True

    def on_stop(self):
        pass


class Application(Worker):
    """Docstring"""

    def __init__(self, ioc):
        Worker.__init__(self, ioc)
        self.ioc.workers.add(Const.W_SUPERV_NAME, Const.G_CORE_NAME, self)
        self.log = ioc.log.err()

    def start(self):
        self.run()

    def _initialize(self):
        logging.info('#'*10 + 'Entering ' + self.__class__.__name__ + '#'*10)
        self._thread = threading.currentThread()

    def _finalize(self):
        self.ioc.message.remove(Const.W_SUPERV_NAME)
        logging.info('#'*10 + 'Leaving ' + self.__class__.__name__ + '#'*10)

    def run(self):
        """Docstring"""
        logging.info('Starting worker %s', id(self))
        self._initialize()
        try:
            LogoApp().run()
        except KeyboardInterrupt:
            pass
        except Exception as e:
            logging.exception(e)

        self._finalize()
        logging.info('Exiting worker %s', id(self))


class Client(Application):
    """Docstring"""
    pass
