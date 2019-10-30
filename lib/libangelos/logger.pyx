# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Logger service that offers specialized logs."""
import logging
from logging.config import dictConfig
from .const import Const
from .utils import Util


class LogHandler:
    """Log handler loaded as a service in the container."""

    def __init__(self, config):
        """Initialize loggers."""
        Util.is_type(config, dict)

        dictConfig(config)

        self.__err = logging.getLogger(Const.LOG_ERR)
        self.__app = logging.getLogger(Const.LOG_APP)
        self.__biz = logging.getLogger(Const.LOG_BIZ)

    @property
    def err(self):
        """Technical error logger."""
        return self.__err

    @property
    def app(self):
        """Application event logger."""
        return self.__app

    @property
    def biz(self):
        """Biz transaction logger."""
        return self.__biz
