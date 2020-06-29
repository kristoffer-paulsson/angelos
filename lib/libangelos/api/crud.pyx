# cython: language_level=3
#
# Copyright (c) 2018-2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Facade contact API."""
import os
from typing import Set

from libangelos.api.api import ApiFacadeExtension
from libangelos.facade.base import BaseFacade
from libangelos.misc import Misc


class CrudAPI(ApiFacadeExtension):
    """Crud API implements the underlying functionality for a RESTful API."""

    ATTRIBUTE = ("crud",)

    def __init__(self, facade: BaseFacade):
        """Initialize the Crud."""
        ApiFacadeExtension.__init__(self, facade)


    async def create(self, url: str, data: bytearray) -> bool:
        """Create a file.

        Args:
            url (str):
                Angelos url to file to be created
            data (bytearray):
                Data to be written to new file

        Returns (bool):
            Success of failure

        """
        parts = Misc.urlparse(url)
        storage = getattr(self.facade.storage, parts["hostname"], None)
        is_file = await storage.archive.isfile(parts["path"])
        if is_file:
            raise OSError("%s already exists in %s" % (parts["path"], parts["hostname"]))

        await storage.archive.mkfile(parts["path", data])
        return True

    async def read(self, url: str) -> bytearray:
        """Read a file.

        Args:
            url (str):
                Angelos url to file to be read

        Returns (bytearray):
            Data from read file

        """
        parts = Misc.urlparse(url)
        storage = getattr(self.facade.storage, parts["hostname"], None)
        is_file = await storage.archive.isfile(parts["path"])
        if not is_file:
            raise OSError("%s not found in %s" % (parts["path"], parts["hostname"]))

        return await storage.archive.load(parts["path"])

    async def update(self, url: str, data: bytearray) -> bool:
        """Update a file.

        Args:
            url (str):
                Angelos url to the file to be updated
            data (bytearray):
                Updated data

        Returns (bool):
            Success of failure

        """
        parts = Misc.urlparse(url)
        storage = getattr(self.facade.storage, parts["hostname"], None)
        is_file = await storage.archive.isfile(parts["path"])
        if not is_file:
            raise OSError("%s not found in %s" % (parts["path"], parts["hostname"]))

        await storage.archive.save(parts["path"], data)
        return True

    async def delete(self, url: str) -> bool:
        """Delete a file.

        Args:
            url (str):
                Angelos url to the file to be deleted

        Returns (bool):
            Success of failure

        """
        parts = Misc.urlparse(url)
        storage = getattr(self.facade.storage, parts["hostname"], None)
        is_file = await storage.archive.isfile(parts["path"])
        if not is_file:
            raise OSError("%s not found in %s" % (parts["path"], parts["hostname"]))

        await storage.archive.remove(parts["path"])
        return True

    async def list(self, url: str) -> Set[str]:
        """Index list of a directory.

        Args:
            url (str):
                Angelos url

        Returns (Set[str]):
            A set of filenames

        """
        parts = Misc.urlparse(url)
        storage = getattr(self.facade.storage, parts["hostname"], None)
        is_dir = await storage.archive.isdir(parts["path"])
        if not is_dir:
            raise OSError("%s not found in %s" % (parts["path"], parts["hostname"]))

        return await storage.search(
            pattern=os.path.join(parts["path"], "*"),
            deleted=False,
            fields=lambda name, entry: name
        )

