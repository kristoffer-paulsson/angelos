# cython: language_level=3
#
# Copyright (c) 2018-2020 by Kristoffer Paulsson <kristoffer.paulsson@talenten.se>.
#
# This software is available under the terms of the MIT license. Parts are licensed under
# different terms if stated. The legal terms are attached to the LICENSE file and are
# made available on:
#
#     https://opensource.org/licenses/MIT
#
# SPDX-License-Identifier: MIT
#
# Contributors:
#     Kristoffer Paulsson - initial implementation
#
"""Logger service that offers specialized logs."""
import logging
from logging.config import dictConfig
from logging.handlers import RotatingFileHandler

from libangelos.archive7.streams import VirtualFileObject, SingleStreamManager
from libangelos.const import Const
from libangelos.utils import Util


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


class EncryptedLogFileObject(VirtualFileObject):
    """File object with support for encrypted streams."""
    def __init__(self, filename: str, secret: bytes, mode: str = "r"):
        self.__manager = SingleStreamManager(filename, secret)
        VirtualFileObject.__init__(self.__manager.special_stream(0), filename, mode)

    def _close(self):
        self._stream.close()
        self.__manager.close()


class EncryptedRotatingFileHandler(RotatingFileHandler):
    """Encrypted rotating file handler for encrypted logging."""

    def __init__(
        self, filename: str, secret: bytes, mode: str = "a",
        max_bytes: int = 2**21, backup_count: int = 0,
        encoding: str = None, delay: int = False
    ):
        self.__secret = secret
        RotatingFileHandler.__init__(
            self, filename, mode=mode, maxBytes=max_bytes,
            backupCount=backup_count, encoding=encoding, delay=delay
        )

    def _open(self):
        """Open a new fileobject with encrypted wrapper."""
        return EncryptedLogFileObject(self.baseFilename, self.__secret, self.mode)
