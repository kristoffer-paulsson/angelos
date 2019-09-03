# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
import atexit

from .archive7 import Archive7
from .helper import AsyncProxy

from ..policy import PrivatePortfolio


class BaseArchive:

    def __init__(self, filename, secret):
        """Initialize the Mail."""
        self._archive = Archive7.open(filename, secret, Archive7.Delete.HARD)
        atexit.register(self._archive.close)
        self.__stats = self._archive.stats()
        self._closed = False
        self._proxy = AsyncProxy(200)

    @property
    def archive(self):
        return self._archive

    @property
    def stats(self):
        """Stats of underlying archive."""
        return self.__stats

    @property
    def closed(self):
        """Indicate if archive is closed."""
        return self._closed

    def close(self):
        """Close the Archive."""
        if not self._closed:
            self._proxy.quit()
            atexit.unregister(self._archive.close)
            self._archive.close()
            self._closed = True

    @classmethod
    def setup(cls, filename, secret, portfolio: PrivatePortfolio,
              _type=None, role=None, use=None):
        """Create and setup the whole Vault according to policys."""

        arch = Archive7.setup(
            filename, secret, owner=portfolio.entity.id,
            node=next(iter(portfolio.nodes)).id,
            domain=portfolio.domain.id, title=cls.__name__,
            _type=_type, role=role, use=use)

        for i in cls.HIERARCHY:
            arch.mkdir(i)

        arch.close()

        return cls(filename, secret)
