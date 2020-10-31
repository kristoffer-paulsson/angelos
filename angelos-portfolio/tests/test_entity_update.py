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
"""Security tests putting the policies to the test."""
import pyximport; pyximport.install()
from angelos.portfolio.entity.update import UpdatePersonEntity, UpdateMinistryEntity, UpdateChurchEntity
from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.meta.fake import Generate
from angelos.portfolio.entity.create import CreatePersonEntity, CreateMinistryEntity, CreateChurchEntity

from unittest import TestCase


def new_data(first: dict, second: dict, changeables: tuple):
    """Populate new data with old not changeable data."""
    for name, field in first.items():
        if name not in changeables:
            second[name] = field


class TestUpdatePersonEntity(TestCase):
    def test_perform(self):
        first, second = Generate.person_data(2)
        portfolio = CreatePersonEntity().perform(PersonData(**first))
        new_data(first, second, portfolio.entity.changeables())
        data = PersonData(**second)
        with evaluate("Person:Update") as r:
            entity = UpdatePersonEntity().perform(portfolio, data)
            print(portfolio)
            print(r.format())


class TestUpdateMinistryEntity(TestCase):
    def test_perform(self):
        first, second = Generate.ministry_data(2)
        portfolio = CreateMinistryEntity().perform(MinistryData(**first))
        new_data(first, second, portfolio.entity.changeables())
        data = MinistryData(**second)
        with evaluate("Ministry:Update") as r:
            entity = UpdateMinistryEntity().perform(portfolio, data)
            print(portfolio)
            print(r.format())


class TestUpdateChurchEntity(TestCase):
    def test_perform(self):
        first, second = Generate.church_data(2)
        portfolio = CreateChurchEntity().perform(ChurchData(**first))
        new_data(first, second, portfolio.entity.changeables())
        data = ChurchData(**second)
        with evaluate("Ministry:Update") as r:
            entity = UpdateChurchEntity().perform(portfolio, data)
            print(portfolio)
            print(r.format())
