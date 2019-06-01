# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Mail related operations.
"""
from .operation import Operation
from ..policy.policy import SignPolicy


class MailBuilder(Operation, SignPolicy):
    """Build mail messages."""

    def __init__(self, **kwargs):
        Operation.__init__(self)
        SignPolicy.__init__(self, **kwargs)
