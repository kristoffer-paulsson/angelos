# cython: language_level=3
"""

Copyright (c) 2018-1019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Commonly used types and functions go here.
"""
import datetime
import abc
from dataclasses import dataclass
from typing import Union, List

from ..misc import BaseDataClass


class PortfolioABC(metaclass=abc.ABCMeta):
    pass


class PrivatePortfolioABC(metaclass=abc.ABCMeta):
    pass


@dataclass
class PersonData(BaseDataClass):
    """Initial data for Person document."""
    given_name: str
    family_name: str
    names: List[str]
    sex: str
    born: datetime.date

    def _asdict(self) -> dict:
        return {
            'given_name': self.given_name,
            'family_name': self.family_name,
            'names': self.names,
            'sex': self.sex,
            'born': self.born
        }


@dataclass
class MinistryData(BaseDataClass):
    """Initial data for Ministry document."""
    ministry: str
    vision: str
    founded: datetime.date

    def _asdict(self) -> dict:
        return {
            'ministry': self.ministry,
            'vision': self.vision,
            'founded': self.founded
        }


@dataclass
class ChurchData(BaseDataClass):
    """Initial data for Church document."""
    city: str
    region: str
    country: str
    founded: datetime.date

    def _asdict(self) -> dict:
        return {
            'city': self.city,
            'region': self.region,
            'country': self.country,
            'founded': self.founded
        }


EntityData = Union[PersonData, MinistryData, ChurchData]
