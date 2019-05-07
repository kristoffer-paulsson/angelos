# cython: language_level=3
"""Module docstring."""
import os
import signal
import functools
import asyncio
import collections
import json
import socket

from ..utils import Util, Event
from ..const import Const
from ..ioc import Container, ContainerAware, Config, Handle
from ..starter import Starter
from ..worker import Worker

from .state import StateMachine
from ..logger import LogHandler
from ..ssh.ssh import SessionManager
from ..facade.facade import Facade
from ..automatic import Automatic
from .parser import Parser

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
            'state': lambda self: StateMachine(self.config['state']),
            'log': lambda self: LogHandler(self.config['logger']),
            'session': lambda self: SessionManager(),
            'facade': lambda self: Handle(Facade),
            'boot': lambda self: Handle(asyncio.base_events.Server),
            'admin': lambda self: Handle(asyncio.base_events.Server),
            'opts': lambda self: Parser(),
            'auto': lambda self: Automatic(self.opts),
            'quit': lambda self: Event(),
        }


class Server(ContainerAware):
    """Main server application class."""

    def __init__(self):
        """Initialize app logger."""
        ContainerAware.__init__(self, Configuration())
        self._worker = Worker('server.main', self.ioc, executor=0, new=False)
        self._applog = self.ioc.log.app

    def _initialize(self):
        self.ioc.state('running', True)
        loop = self._worker.loop

        loop.add_signal_handler(
            signal.SIGINT, functools.partial(self.quiter, signal.SIGINT))

        loop.add_signal_handler(
            signal.SIGTERM, functools.partial(self.quiter, signal.SIGTERM))

        self._worker.run_coroutine(self.boot_server())
        self._worker.run_coroutine(self.admin_server())
        self._worker.run_coroutine(self.boot_activator())

        self._applog.info('Starting boot server.')

    def _finalize(self):
        self._applog.info('Shutting down server.')
        self._applog.info('Server quitting.')

    def _listen(self):
        la = self.ioc.env['opts'].listen
        if la == 'localhost':
            listen = 'localhost'
        elif la == 'loopback':
            listen = '127.0.0.1'
        elif la == 'hostname':
            listen = self.ioc.env['net'].hostname
        elif la == 'domain':
            listen = self.ioc.env['net'].domain
        elif la == 'ip':
            listen = self.ioc.env['net'].ip
        elif la == 'any':
            listen = ''
        else:
            listen = la
        return listen

    def quiter(self, signame):
        """
        Callback that trigger quit on SIGINT and SIGTERM.

        When a signal occur this handler sets the quit event
        and raises a KeyboardInterrupt
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

    async def admin_server(self):
        first = True
        while not self.ioc.quit.is_set():
            if self.ioc.state.position('serving'):
                await self.ioc.state.off('serving')
                server = self.ioc.admin
                server.close()
                await self.ioc.session.unreg_server('admin')
                await server.wait_closed()
            else:
                await self.ioc.state.on('serving')
                if first:
                    self.ioc.admin = await Starter().admin_server(
                        self._listen(), port=self.ioc.env['opts'].port,
                        ioc=self.ioc, loop=self._worker.loop)
                    self.ioc.session.reg_server('admin', self.ioc.admin)
                    first = False
                else:
                    await self.ioc.admin.start_serving()

    async def boot_server(self):
        first = True
        while not self.ioc.quit.is_set():
            if self.ioc.state.position('boot'):
                await self.ioc.state.off('boot')
                server = self.ioc.boot
                server.close()
                await self.ioc.session.unreg_server('boot')
                await server.wait_closed()
            else:
                await self.ioc.state.on('boot')
                if first:
                    self.ioc.boot = await Starter().boot_server(
                        self._listen(), port=self.ioc.env['opts'].port,
                        ioc=self.ioc, loop=self._worker.loop)
                    self.ioc.session.reg_server('boot', self.ioc.boot)
                    first = False
                else:
                    await self.ioc.boot.start_serving()

    async def boot_activator(self):
        await asyncio.sleep(1)
        self.ioc.state('boot', True)
