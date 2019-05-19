import os
import io
import random
import string
import datetime

from lipsum import (
    SURNAMES, MALE_NAMES, FEMALE_NAMES, LIPSUM_LINES, LIPSUM_WORDS, CHURCHES)


def filesize(file):
    if isinstance(file, io.IOBase):
        return os.fstat(file.fileno()).st_size
    else:
        return os.stat(file).st_size


def random_person_entity_data(num=1):
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

        identities.append({
            'given_name': names[0],
            'names': names,
            'family_name': random.choices(SURNAMES, k=1)[0].capitalize(),
            'sex': sex,
            'born': born
        })

    return identities


def random_ministry_entity_data(num=1):
    ministries = []
    for i in range(num):
        ministry = random.choices(LIPSUM_WORDS, k=random.randrange(3, 7))
        vision = random.choices(LIPSUM_WORDS, k=random.randrange(20, 25))
        founded = datetime.date.today(
            ) - datetime.timedelta(days=random.randrange(365, 29220))

        ministries.append({
            'ministry': ' '.join(ministry).capitalize(),
            'vision': ' '.join(vision).capitalize(),
            'founded': founded
        })

    return ministries


def random_church_entity_data(num=1):
    churches = []
    for i in range(num):
        church = random.choices(CHURCHES, k=1)[0]
        founded = datetime.date.today(
            ) - datetime.timedelta(days=random.randrange(730, 29220))

        churches.append({
            'founded': founded,
            'city': church[0],
            'region': church[1],
            'country': church[2]
        })

    return churches


def generate_data():
    return ('\n'.join(
        random.choices(
            LIPSUM_LINES,
            k=random.randrange(1, 10)))).encode('utf-8')


def generate_filename(postfix='.txt'):
    return ''.join(random.choices(
        string.ascii_lowercase + string.digits,
        k=random.randrange(5, 10))) + postfix
