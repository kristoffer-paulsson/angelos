# cython: language_level=3
"""

Copyright (c) 2018-2019, Kristoffer Paulsson <kristoffer.paulsson@talenten.se>

This file is distributed under the terms of the MIT license.


Random dummy data generators."""
import os
import io
import random
import string
import datetime

from lipsum import (
    SURNAMES, MALE_NAMES, FEMALE_NAMES, LIPSUM_LINES, LIPSUM_WORDS, CHURCHES)

from angelos.policy import PersonData, MinistryData, ChurchData


def filesize(file):
    """Real file filesize reader."""
    if isinstance(file, io.IOBase):
        return os.fstat(file.fileno()).st_size
    else:
        return os.stat(file).st_size


def random_person_entity_data(num=1):
    """Generate random entity data for number of person entities."""
    identities = []
    for i in range(num):
        sex = random.choices(
            ['man', 'woman', 'undefined'], [.495, .495, .01], k=1)[0]
        if sex == 'man':
            names = random.choices(MALE_NAMES, k=random.randrange(2, 5))
        elif sex == 'woman':
            names = random.choices(FEMALE_NAMES, k=random.randrange(2, 5))
        else:
            names = random.choices(
                MALE_NAMES + FEMALE_NAMES, k=random.randrange(2, 5))

        born = datetime.date.today(
            ) - datetime.timedelta(days=random.randrange(4748, 29220))

        entity = PersonData()
        entity.given_name = names[0]
        entity.names = names
        entity.family_name = random.choices(SURNAMES, k=1)[0].capitalize()
        entity.sex = sex
        entity.born = born
        identities.append(entity)

    return identities


def random_ministry_entity_data(num=1):
    """Generate random entity data for number of ministry entities."""
    ministries = []
    for i in range(num):
        ministry = random.choices(LIPSUM_WORDS, k=random.randrange(3, 7))
        vision = random.choices(LIPSUM_WORDS, k=random.randrange(20, 25))
        founded = datetime.date.today(
            ) - datetime.timedelta(days=random.randrange(365, 29220))

        entity = MinistryData()
        entity.ministry = ' '.join(ministry).capitalize()
        entity.vision = ' '.join(vision).capitalize()
        entity.founded = founded
        ministries.append(entity)

    return ministries


def random_church_entity_data(num=1):
    """Generate random entity data for number of church entities."""
    churches = []
    for i in range(num):
        church = random.choices(CHURCHES, k=1)[0]
        founded = datetime.date.today(
            ) - datetime.timedelta(days=random.randrange(730, 29220))

        entity = ChurchData()
        entity.founded = founded
        entity.city = church[0]
        entity.region = church[1]
        entity.country = church[2]
        churches.append(entity)

    return churches


def generate_data():
    """Random lipsum data generator."""
    return ('\n'.join(
        random.choices(
            LIPSUM_LINES,
            k=random.randrange(1, 10)))).encode('utf-8')


def generate_filename(postfix='.txt'):
    """Random file name generator."""
    return ''.join(random.choices(
        string.ascii_lowercase + string.digits,
        k=random.randrange(5, 10))) + postfix
