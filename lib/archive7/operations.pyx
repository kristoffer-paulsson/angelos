# cython: language_level=3
#
# Copyright (c) 2020 by:
# Kristoffer Paulsson <kristoffer.paulsson@talenten.se>
# This file is distributed under the terms of the MIT license.
#
"""Data streams operations."""
from abc import ABC


class StreamOperation(ABC):
    """Base class for operations on stream managers, streams and blocks."""
    pass


class ZipOperation(StreamOperation):
    """Zip streams."""
    pass


class VacuumOperation(StreamOperation):
    """Vacuums an archive and removes the trash."""
    pass


class ReEncryptOperation(StreamOperation):
    """Re-encrypts an archive with a new key."""
    pass


class ShredOperation(ReEncryptOperation):
    """Generates a new key and re-encrypts, then throws the key away."""
    pass