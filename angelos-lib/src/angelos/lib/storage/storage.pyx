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
"""Module docstring"""
import atexit
import os
import uuid

from angelos.archive7.archive import Archive7
from angelos.archive7.fs import Delete
from angelos.lib.facade.base import BaseFacade, FacadeExtension


class StorageFacadeExtension(FacadeExtension):
    """Archive extension to isolate the archives."""

    ATTRIBUTE = ("",)
    CONCEAL = ("",)
    USEFLAG = (0,)

    INIT_HIERARCHY = ("/",)
    INIT_FILES = ()

    def __init__(self, facade: BaseFacade, home_dir: str, secret: bytes, delete=Delete.HARD):
        """Initialize the Storage extension."""
        FacadeExtension.__init__(self, facade)
        self.__archive = Archive7.open(self.filename(home_dir), secret, delete)
        atexit.register(self.__archive.close)
        self.__closed = False

    @property
    def archive(self):
        """Property access to underlying storage.

        Returns:

        """
        return self.__archive

    @property
    def closed(self) -> bool:
        """Indicate if archive is closed."""
        return self.__closed

    def close(self):
        """Close the Archive."""
        if not self.__closed:
            atexit.unregister(self.__archive.close)
            self.__archive.close()
            self.__closed = True

    @classmethod
    async def setup(
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
        archive = Archive7.setup(
            cls.filename(home_dir),
            secret,
            owner=owner,
            node=node,
            domain=domain,
            title=cls.ATTRIBUTE[0],
            type_=vtype,
            role=vrole,
            use=cls.USEFLAG[0],
        )
        await cls._hierarchy(archive)
        await cls._files(archive)
        archive.close()

        return cls(facade, home_dir, secret)

    @classmethod
    def filename(cls, dir_name):
        """

        Args:
            dir_name:

        Returns:

        """
        return os.path.join(dir_name, cls.CONCEAL[0])

    @classmethod
    async def _hierarchy(cls, archive):
        for i in cls.INIT_HIERARCHY:
            await archive.mkdir(i)

    @classmethod
    async def _files(cls, archive):
        for i in cls.INIT_FILES:
            await archive.mkfile(i[0], i[1])
