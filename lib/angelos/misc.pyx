# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Module docstring."""
import abc
from dataclasses import dataclass, asdict as data_asdict


@dataclass
class BaseDataClass(metaclass=abc.ABCMeta):
    """A base dataclass with some basic functions"""

    def _asdict(self) -> dict:
        return data_asdict(self)
