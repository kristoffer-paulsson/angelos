"""Docstring"""
import collections
import yaml

from .server import Server
from .common import IMMUTABLE, DEFAULT
from ..ioc import Container

from ..worker import Workers
from ..events import Events
from ..logger import LogHandler

with open('default.yaml') as yc:
    LOADED = yaml.load(yc.read())

CONFIG = {
    'workers': lambda self: Workers(),
    'environment': lambda self: collections.ChainMap(
        IMMUTABLE,
        LOADED,
        DEFAULT),
    'message': lambda self: Events(),
    'log': lambda self: LogHandler(self.environment['logger']),
}


def start():
    """Docstring"""
    Server(Container(CONFIG)).start()
