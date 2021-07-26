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
from abc import ABCMeta
from collections import namedtuple
from typing import Union


class PortfolioABC(metaclass=ABCMeta):
    pass


class PrivatePortfolioABC(metaclass=ABCMeta):
    pass


PersonData = namedtuple("PersonData", "given_name,family_name,names,sex,born")


MinistryData = namedtuple("MinistryData", "ministry,vision,founded")


ChurchData = namedtuple("ChurchData", "city,region,country,founded")


EntityDataT = Union[PersonData, MinistryData, ChurchData]
