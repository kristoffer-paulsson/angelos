# cython: language_level=3
"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


"""
from .archive7 import Archive7


class BaseArchive:
    """
    Class docstring.

    Hello world.
    """

    def __init__(self, filename, secret, delete=Archive7.Delete.HARD):
        """Docstring. Initialize archive."""
        self._archive = Archive7.open(filename, secret, delete)
        self._closed = False
