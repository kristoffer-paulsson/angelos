# cython: language_level=3
#
# Copyright (c) 2018-2019 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Module docstring"""
import os
import uuid
import atexit

from ..facade.base import BaseFacade, FacadeExtension
from ..archive7 import Archive7
from ..helper import AsyncProxy

from ..policy.portfolio import PrivatePortfolio


class StorageFacadeExtension(FacadeExtension):
    """Archive extension to isolate the archives."""

    ATTRIBUTE = ("",)
    CONCEAL = ("",)
    USEFLAG = (0,)

    HIERARCHY = ("/")

    def __init__(self, facade: BaseFacade, home_dir: str, secret: bytes, delete=Archive7.Delete.HARD):
        """Initialize the Mail."""
        FacadeExtension.__init__(self, facade)
        self.__archive = Archive7.open(self.filename(home_dir), secret, delete)
        atexit.register(self.__archive.close)
        self.__closed = False
        self.__proxy = AsyncProxy(200)

    @property
    def archive(self):
        return self.__archive

    @property
    def proxy(self):
        return self.__proxy

    @property
    def closed(self):
        """Indicate if archive is closed."""
        return self.__closed

    def close(self):
        """Close the Archive."""
        if not self.__closed:
            self.__proxy.quit()
            atexit.unregister(self.__archive.close)
            self.__archive.close()
            self.__closed = True

    @classmethod
    def setup(
        cls,
        facade: BaseFacade,
        home_dir: str,
        secret: bytes,
        owner: uuid.UUID,
        node: uuid.UUID,
        domain: uuid.UUID,
        vtype=None,
        vrole=None,
    ):
        """Create and setup the whole Vault according to policy's."""
        arch = Archive7.setup(
            cls.filename(home_dir),
            secret,
            owner=owner,
            node=node,
            domain=domain,
            title=cls.ATTRIBUTE[0],
            _type=vtype,
            role=vrole,
            use=cls.USEFLAG[0],
        )
        cls._hierarchy(arch)
        arch.close()

        return cls(facade, home_dir, secret)

    @classmethod
    def filename(cls, dir_name):
        return os.path.join(dir_name, cls.CONCEAL[0])

    @classmethod
    def _hierarchy(cls, archive):
        for i in cls.HIERARCHY:
            archive.mkdir(i)
