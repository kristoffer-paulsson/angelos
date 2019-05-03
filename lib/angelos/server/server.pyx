# cython: language_level=3
"""Module docstring."""
import os
import signal
import functools
import asyncio

from ..utils import Util
from ..const import Const
from ..ioc import ContainerAware
from ..starter import Starter


class Server(ContainerAware):
    """Main server application class."""

    def __init__(self, ioc):
        """Initialize app logger."""
        ContainerAware.__init__(self, ioc)
        self._applog = self.ioc.log.app

    def _initialize(self):
        loop = asyncio.get_event_loop()

        loop.add_signal_handler(
            signal.SIGINT, functools.partial(self.quiter, signal.SIGINT))

        loop.add_signal_handler(
            signal.SIGTERM, functools.partial(self.quiter, signal.SIGTERM))

        self._applog.info('Starting boot server.')
        self.ioc.boot = Starter().boot_server(
            self._listen(), port=self.ioc.env['port'], ioc=self.ioc)

    def _finalize(self):
        self._applog.info('Shutting down server.')
        self._applog.info('Server quitting.')

    def _listen(self):
        la = self.ioc.env['listen']
        if la == 'localhost':
            listen = 'localhost'
        elif la == 'loopback':
            listen = '127.0.0.1'
        elif la == 'hostname':
            listen = self.ioc.env['hostname']
        elif la == 'domain':
            listen = self.ioc.env['domain']
        elif la == 'ip':
            listen = self.ioc.env['ip']
        elif la == 'any':
            listen = ''
        else:
            listen = la
        return listen

    def quiter(self, signame):
        """
        Coroutine that waits for Quit.

        When the Quit event happens it raises a KeyboardInterrupt to stop the
        run_forever of the main event loop. Initiating the shutdown sequence.
        """
        self.ioc.quit.set()
        raise KeyboardInterrupt(signame)

    def run(self):
        """Run the server applications main loop."""
        self._applog.info('-------- STARTING SERVER --------')

        self._initialize()
        try:
            asyncio.get_event_loop().run_forever()
        except KeyboardInterrupt:
            pass
        except Exception as e:
            self._applog.critical(
                'Server crashed due to unhandled exception: %s' % e)
            self._applog.exception(e)
        self._finalize()

        self._applog.info('-------- EXITING SERVER --------')
