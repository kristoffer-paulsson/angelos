"""Docstring"""
import collections

from .server import Server
from .common import IMMUTABLE, DEFAULT
from ..ioc import Container

from ..worker import Workers
from ..events import Events
from ..logger import LogHandler


CONFIG = {
    'workers': lambda self: Workers(),
    'environment': lambda self: collections.ChainMap(
        IMMUTABLE,
        # configparser.ConfigParser().read(
        #    Util.app_dir() + '/angelos.ini')._sections,
        DEFAULT),
    'message': lambda self: Events(),
    'log': lambda self: LogHandler(self.environment['logger']),
}


def start():
    """Docstring"""
    app = Server(Container(CONFIG))
    app.start()
