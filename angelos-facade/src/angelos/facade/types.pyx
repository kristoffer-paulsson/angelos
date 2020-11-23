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
import datetime
from typing import NamedTuple, List, Optional


class PersonData(NamedTuple):
    """Person entity document data tuple."""

    given_name: str
    family_name: str
    names: List[str]
    sex: str
    born: datetime.date


class MinistryData(NamedTuple):
    """Ministry entity document data tuple."""

    ministry: str
    vision: Optional[str]
    founded: datetime.date


class ChurchData(NamedTuple):
    """Church entity document data tuple."""

    city: str
    region: Optional[str]
    country: Optional[str]
    founded: datetime.date