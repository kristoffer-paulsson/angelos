"""Module docstring."""
import logging
from logging.config import dictConfig
from .const import Const
from .utils import Util


class LogHandler:
    """Docstring"""
    def __init__(self, config):
        """Docstring"""
        Util.is_type(config, dict)

        dictConfig(config)

        self.__err = logging.getLogger(Const.LOG_ERR)
        self.__app = logging.getLogger(Const.LOG_APP)
        self.__biz = logging.getLogger(Const.LOG_BIZ)

    def err(self):
        """Docstring"""
        return self.__err

    def app(self):
        """Docstring"""
        return self.__app

    def biz(self):
        """Docstring"""
        return self.__biz
