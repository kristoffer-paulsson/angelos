"""Docstring"""
import threading
import logging
from kivy.app import App
from kivymd.theming import ThemeManager

from ..const import Const
from ..worker import Worker
from .backend import Backend
from .ui.manager import InterfaceManager


class LogoApp(App):
    theme_cls = ThemeManager()
    title = "Logo"
    ioc = None

    def build(self):
        return InterfaceManager(configured=self.ioc.environment['configured'])
        # self.theme_cls.theme_style = 'Dark'

    def on_pause(self):
        return True

    def on_stop(self):
        self.ioc.workers.stop()


class Application(Worker):
    """Docstring"""

    def __init__(self, ioc):
        Worker.__init__(self, ioc)
        self.ioc.workers.add(Const.W_SUPERV_NAME, Const.G_CORE_NAME, self)
        self.log = ioc.log.err()
        self.app = None

    def start(self):
        self.run()

    def _initialize(self):
        logging.info('#'*10 + 'Entering ' + self.__class__.__name__ + '#'*10)
        self._thread = threading.currentThread()
        self.__start_backend()

    def _finalize(self):
        self.ioc.message.remove(Const.W_SUPERV_NAME)
        logging.info('#'*10 + 'Leaving ' + self.__class__.__name__ + '#'*10)

    def run(self):
        """Docstring"""
        logging.info('Starting worker %s', id(self))
        self._initialize()
        try:
            self.app = LogoApp()
            self.app.ioc = self.ioc
            self.app.run()
        except KeyboardInterrupt:
            pass
        except Exception as e:
            logging.exception(e)

        self._finalize()
        logging.info('Exiting worker %s', id(self))

    def __start_backend(self):
        logging.info('#'*10 + 'Entering __start_backend' + '#'*10)
        be = Backend(self.ioc)
        be.start()
        self.ioc.workers.add(Const.W_BACKEND_NAME, Const.G_CORE_NAME, be)
        logging.info('#'*10 + 'Leaving __start_Backend' + '#'*10)

    def stop(self):
        """Docstring"""
        self._halt.set()


class Client(Application):
    """Docstring"""
    pass
