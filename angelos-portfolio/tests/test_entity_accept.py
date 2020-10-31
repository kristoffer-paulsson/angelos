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
import copy

from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData
from angelos.meta.fake import Generate
from angelos.portfolio.entity.accept import ValidateEntity, AcceptUpdatedEntity, AcceptNewKeys
from angelos.portfolio.entity.newkey import NewKeys
from angelos.portfolio.entity.update import UpdatePersonEntity
from angelos.portfolio.entity.create import CreatePersonEntity
from angelos.portfolio.portfolio.setup import SetupPersonPortfolio

from unittest import TestCase


def new_data(first: dict, second: dict, changeables: tuple):
    """Populate new data with old not changeable data."""
    for name, field in first.items():
        if name not in changeables:
            second[name] = field


class TestValidateEntity(TestCase):
    def test_validate(self):
        data = PersonData(**Generate.person_data()[0])
        portfolio = SetupPersonPortfolio().perform(data)
        with evaluate("Entity:Validate") as r:
            ValidateEntity().validate(portfolio)
            print(r.format())
            print(portfolio)


class TestAcceptUpdatedEntity(TestCase):
    def test_validate(self):
        first, second = Generate.person_data(2)
        portfolio = CreatePersonEntity().perform(PersonData(**first))
        ext_portfolio = copy.deepcopy(portfolio)
        new_data(first, second, portfolio.entity.changeables())
        data = PersonData(**second)
        entity = UpdatePersonEntity().perform(ext_portfolio, data)
        self.assertNotEqual(entity.export(), portfolio.entity.export())
        with evaluate("Person:AcceptUpdate") as r:
            portfolio = AcceptUpdatedEntity().validate(portfolio, entity)
            print(portfolio)
            print(r.format())


class TestAcceptNewKeys(TestCase):
    def test_validate(self):
        portfolio = CreatePersonEntity().perform(PersonData(**Generate.person_data()[0]))
        ext_portfolio = copy.deepcopy(portfolio)
        keys, privkeys = NewKeys().perform(ext_portfolio)
        with evaluate("Person:AcceptNewKeys") as r:
            portfolio = AcceptNewKeys().validate(portfolio, keys, privkeys)
            print(portfolio)
            print(r.format())