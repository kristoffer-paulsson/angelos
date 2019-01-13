"""Docstring"""
import collections
import yaml

from .client import Client
from .common import IMMUTABLE, DEFAULT
from ..ioc import Container

from ..worker import Workers
from ..events import Events
from ..logger import LogHandler
from ..runtime import Runtime
from ..facade.person import PersonFacade

try:
    with open(DEFAULT['runtime']['root'] + '/default.yml') as yc:
        LOADED = yaml.load(yc.read())
except FileNotFoundError:
    LOADED = {'configured': False}

CONFIG = {
    'workers': lambda self: Workers(),
    'environment': lambda self: collections.ChainMap(
        IMMUTABLE,
        LOADED,
        DEFAULT),
    'message': lambda self: Events(),
    'log': lambda self: LogHandler(self.environment['logger']),
    'runtime': lambda self: Runtime(self.environment['runtime']),
    'facade': lambda self: PersonFacade(
        self.runtime.root(), self.environment['key'])  # noqa E501
}


def start():
    """Docstring"""
    Client(Container(CONFIG)).start()
