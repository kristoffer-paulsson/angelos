"""Module docstring."""
import collections
import json

from .app import Application
from .vars import (
    ENV_DEFAULT, ENV_IMMUTABLE, CONFIG_DEFAULT, CONFIG_IMMUTABLE)
from ..ioc import Container

from ..logger import LogHandler
from ..runtime import Runtime
from .parser import Parser

try:
    with open(ENV_DEFAULT['runtime']['home'] + '/env.json') as jc:
        ENV_LOADED = json.load(jc.read())
except FileNotFoundError:
    ENV_LOADED = {}

try:
    with open(ENV_DEFAULT['runtime']['home'] + '/config.json') as jc:
        CONFIG_LOADED = json.load(jc.read())
except FileNotFoundError:
    CONFIG_LOADED = {}

CONFIG = {
    'env': lambda self: collections.ChainMap(
        ENV_IMMUTABLE,
        ENV_LOADED,
        ENV_DEFAULT),
    'config': lambda self: collections.ChainMap(
        CONFIG_IMMUTABLE,
        CONFIG_LOADED,
        CONFIG_DEFAULT),
    'log': lambda self: LogHandler(self.config['logger']),
    'runtime': lambda self: Runtime(self.config['runtime']),
    'opts': lambda self: Parser(),
}


def start():
    """Start server application."""
    Application(Container(CONFIG)).run()
