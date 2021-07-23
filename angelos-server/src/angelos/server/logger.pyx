# cython: language_level=3, linetrace=True
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
from logging.handlers import RotatingFileHandler
from pathlib import Path

from angelos.archive7.streams import VirtualFileObject, SingleStreamManager
from angelos.lib.ioc import LogAware


class EncryptedLogFileObject(VirtualFileObject):
    """File object with support for encrypted streams."""
    def __init__(self, filename: str, secret: bytes, mode: str = "r"):
        self.__manager = SingleStreamManager(filename, secret)
        VirtualFileObject.__init__(self, self.__manager.special_stream(0), filename, mode)

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


class Logger:
    """Logger that is initiated together with the IoC."""

    def __init__(self, secret: bytes, path: Path):
        logging.addLevelName(LogAware.NORMAL[0], "NORMAL")
        logging.addLevelName(LogAware.WARNING[0], "WARNING")
        logging.addLevelName(LogAware.CRITICAL[0], "CRITICAL")

        logger = logging.getLogger()
        logger.setLevel(LogAware.NORMAL[0])
        handler = EncryptedRotatingFileHandler(
            filename=str(path.joinpath("nominal.log")), secret=secret)
        handler.setFormatter(logging.Formatter(
            fmt="%(asctime)s %(name)s:%(levelname)s %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        ))
        logger.addHandler(handler)
