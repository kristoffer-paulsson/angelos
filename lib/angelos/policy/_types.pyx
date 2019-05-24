# cython: language_level=3
"""Commonly used types and functions go here."""
import datetime
import abc
from dataclasses import dataclass
from typing import Union, List


class PortfolioABC(metaclass=abc.ABCMeta):
    pass


class PrivatePortfolioABC(metaclass=abc.ABCMeta):
    pass


@dataclass
class PersonData:
    """Initial data for Person document."""
    __slots__ = ('given_name', 'family_name', 'names', 'sex', 'born')
    given_name: str
    family_name: str
    names: List[str]
    sex: str
    born: datetime.date


@dataclass
class MinistryData:
    """Initial data for Ministry document."""
    __slots__ = ('ministry', 'vision', 'founded')
    ministry: str
    vision: str
    founded: datetime.date


@dataclass
class ChurchData:
    """Initial data for Church document."""
    __slots__ = ('city', 'region', 'country', 'founded')
    city: str
    region: str
    country: str
    founded: datetime.date


EntityData = Union[PersonData, MinistryData, ChurchData]
