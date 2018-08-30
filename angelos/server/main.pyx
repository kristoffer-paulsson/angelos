import logging

from .server import Server
from .common import CONFIG
from ..ioc import Container


def start():
    logging.basicConfig(level=logging.DEBUG)
    app = Server(Container(CONFIG))
    app.start()
