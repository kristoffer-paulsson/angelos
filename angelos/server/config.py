"""Module docstring."""
import collections
import json
import asyncio


from .vars import (
    ENV_DEFAULT, ENV_IMMUTABLE, CONFIG_DEFAULT, CONFIG_IMMUTABLE)

from ..ioc import Handle
from ..facade.facade import Facade
from ..logger import LogHandler
from ..automatic import Automatic
from .parser import Parser

try:
    with open(ENV_DEFAULT['root'] + '/env.json') as jc:
        ENV_LOADED = json.load(jc.read())
except FileNotFoundError:
    ENV_LOADED = {}

try:
    with open(ENV_DEFAULT['root'] + '/config.json') as jc:
        CONFIG_LOADED = json.load(jc.read())
except FileNotFoundError:
    CONFIG_LOADED = {}

CONFIG = {
    'env': lambda self: collections.ChainMap(
        ENV_IMMUTABLE,
        vars(self.opts.args),
        vars(self.auto),
        ENV_LOADED,
        ENV_DEFAULT),
    'config': lambda self: collections.ChainMap(
        CONFIG_IMMUTABLE,
        CONFIG_LOADED,
        CONFIG_DEFAULT),
    'log': lambda self: LogHandler(self.config['logger']),
    'facade': lambda self: Handle(Facade),
    'boot': lambda self: Handle(asyncio.Server),
    'opts': lambda self: Parser(),
    'auto': lambda self: Automatic(),
    'quit': lambda self: asyncio.Event(),
}
