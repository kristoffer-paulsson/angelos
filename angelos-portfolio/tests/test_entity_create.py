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
import pyximport;
from angelos.common.policy import evaluate
from angelos.lib.policy.types import PersonData, MinistryData, ChurchData
from angelos.meta.fake import Generate
from angelos.portfolio.entity.create import CreatePersonEntity, CreateMinistryEntity, CreateChurchEntity

pyximport.install()

from unittest import TestCase


class TestCreatePersonEntity(TestCase):
    def test_perform(self):
        data = PersonData(**Generate.person_data()[0])
        with evaluate("Person:Create") as r:
            portfolio = CreatePersonEntity().perform(data)
            print(r.format())


class TestCreateMinistryEntity(TestCase):
    def test_perform(self):
        data = MinistryData(**Generate.ministry_data()[0])
        with evaluate("Ministry:Create") as r:
            portfolio = CreateMinistryEntity().perform(data)
            print(r.format())


class TestCreateChurchEntity(TestCase):
    def test_perform(self):
        data = ChurchData(**Generate.church_data()[0])
        with evaluate("Church:Create") as r:
            portfolio = CreateChurchEntity().perform(data)
            print(r.format())
