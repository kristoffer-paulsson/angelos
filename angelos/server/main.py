import logging
import collections

from .server import Server
from .common import IMMUTABLE, DEFAULT
from ..ioc import Container

from ..worker import Workers
from ..events import Events


CONFIG = {
    'workers': lambda self: Workers(),
    'environment': lambda self: collections.ChainMap(
        IMMUTABLE,
        # configparser.ConfigParser().read(
        #    Util.app_dir() + '/angelos.ini')._sections,
        DEFAULT),
    'message': lambda self: Events()
}


def start():
    logging.basicConfig(level=logging.DEBUG)
    app = Server(Container(CONFIG))
    app.start()
