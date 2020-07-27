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
"""Commonly used types and functions go here."""
import datetime
from abc import ABCMeta
from collections import namedtuple
from dataclasses import dataclass
from typing import Union, List

from angelos.common.misc import BaseDataClass


class PortfolioABC(metaclass=ABCMeta):
    pass


class PrivatePortfolioABC(metaclass=ABCMeta):
    pass

"""
@dataclass
class PersonData(BaseDataClass):

    given_name: str
    family_name: str
    names: List[str]
    sex: str
    born: datetime.date

    def _asdict(self) -> dict:
        return {
            "given_name": self.given_name,
            "family_name": self.family_name,
            "names": self.names,
            "sex": self.sex,
            "born": self.born,
        }
"""

PersonData = namedtuple("PersonData", "given_name,family_name,names,sex,born")


"""
@dataclass
class MinistryData(BaseDataClass):

    ministry: str
    vision: str
    founded: datetime.date

    def _asdict(self) -> dict:
        return {
            "ministry": self.ministry,
            "vision": self.vision,
            "founded": self.founded,
        }
"""

MinistryData = namedtuple("MinistryData", "ministry,vision,founded")

"""
@dataclass
class ChurchData(BaseDataClass):

    city: str
    region: str
    country: str
    founded: datetime.date

    def _asdict(self) -> dict:
        return {
            "city": self.city,
            "region": self.region,
            "country": self.country,
            "founded": self.founded,
        }
"""


ChurchData = namedtuple("ChurchData", "city,region,country,founded")


EntityDataT = Union[PersonData, MinistryData, ChurchData]
