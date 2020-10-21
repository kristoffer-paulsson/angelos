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
import pyximport
from angelos.portfolio.collection import Operations

pyximport.install()

import contextlib
from unittest import TestCase

from angelos.common.policy import evaluate, PolicyBreachException
from angelos.document.entities import Person
from angelos.lib.operation.setup import SetupPersonOperation, PersonData, SetupMinistryOperation, MinistryData, \
    ChurchData, SetupChurchOperation
from angelos.meta.fake import Generate
from angelos.portfolio.entity import PersonEntityValidator


class TestPersonEntityValidator(TestCase):
    def test_validate_person(self):
        portfolio = SetupPersonOperation.create(PersonData(**Generate.person_data()[0]))
        with evaluate("Validate:Person:{}".format(portfolio.entity.id)) as r:
            portfolio.entity.validate()
            ops = Operations()
            ops.validate(portfolio)
            print(r.format())

    def test_validate_ministry(self):
        portfolio = SetupMinistryOperation.create(MinistryData(**Generate.ministry_data()[0]))
        with evaluate("Validate:Ministry:{}".format(portfolio.entity.id)) as r:
            portfolio.entity.validate()
            Operations.validate(portfolio)
            print(r.format())

    def test_validate_church(self):
        portfolio = SetupChurchOperation.create(ChurchData(**Generate.church_data()[0]))
        with evaluate("Validate:Church:{}".format(portfolio.entity.id)) as r:
            portfolio.entity.validate()
            Operations.validate(portfolio)
            print(r.format())
