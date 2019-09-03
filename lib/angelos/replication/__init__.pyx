# cython: language_level=3
"""

Copyright (c) 2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Replication logic.

Implementation of the replocator logic and protocol.
"""
from .endpoint import ReplicatorClient, ReplicatorServer
from .handler import ReplicatorClientHandler, ReplicatorServerHandler
from .preset import MailPreset


__all__ = [
    'ReplicatorClient',
    'ReplicatorServer',

    'ReplicatorClientHandler',
    'ReplicatorServerHandler',

    'MailPreset'
]
