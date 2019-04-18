"""Module docstring."""
import collections
import json

from .app import Application
from .common import IMMUTABLE, DEFAULT
from ..ioc import Container

from ..logger import LogHandler
from ..runtime import Runtime

try:
    with open(DEFAULT['runtime']['root'] + '/config.json') as jc:
        LOADED = json.load(jc.read())
except FileNotFoundError:
    LOADED = {'configured': False}

CONFIG = {
    'environment': lambda self: collections.ChainMap(
        IMMUTABLE,
        LOADED,
        DEFAULT),
    'log': lambda self: LogHandler(self.environment['logger']),
    'runtime': lambda self: Runtime(self.environment['runtime']),
}


def start():
    """Docstring"""
    Application(Container(CONFIG)).start()
