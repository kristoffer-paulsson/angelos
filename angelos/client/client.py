"""Docstring"""
import threading
import logging
from kivy.app import App
from kivy.clock import Clock
from kivymd.theming import ThemeManager

from .events import Messages
from ..const import Const
from ..worker import Worker
from .backend import Backend
from .ui.manager import InterfaceManager


class LogoApp(App):
    theme_cls = ThemeManager()
    title = "Logo"
    ioc = None

    def build(self):
        # self.theme_cls.theme_style = 'Dark'
        return InterfaceManager(configured=self.ioc.environment['configured'])

    def on_pause(self):
        return True

    def on_stop(self):
        self.ioc.workers.stop()


class Application(Worker):
    """Docstring"""

    def __init__(self, ioc):
        Worker.__init__(self, ioc)
        self.ioc.workers.add(Const.W_CLIENT_NAME, Const.G_CORE_NAME, self)
        self.log = ioc.log.err()
        self.app = None

    def start(self):
        self.run()

    def _initialize(self):
        logging.info('#'*10 + 'Entering ' + self.__class__.__name__ + '#'*10)
        self.ioc.message.add(Const.W_CLIENT_NAME)
        self._thread = threading.currentThread()
        self.__start_backend()

    def _finalize(self):
        self.ioc.message.remove(Const.W_CLIENT_NAME)
        logging.info('#'*10 + 'Leaving ' + self.__class__.__name__ + '#'*10)

    def run(self):
        """Docstring"""
        logging.info('Starting worker %s', id(self))
        self._initialize()
        try:
            self.app = LogoApp()
            Clock.schedule_interval(self.event_callback(), 1 / 10.)
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

    def event_callback(self):
        def event_reader(dt):
            event = self.ioc.message.receive(Const.W_CLIENT_NAME)

            if event is None:
                return not self._halt.is_set()
            else:
                logging.info(event)

            if event.message == Messages.NEW_INTERFACE:
                if event.data['ui'] is 'default':
                    self.app.root.show_default()
                elif event.data['ui'] is 'spinner':
                    self.app.root.show_spinner()

            return not self._halt.is_set()
        return event_reader


class Client(Application):
    """Docstring"""
    pass
