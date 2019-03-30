import os
import io
import random
import datetime

from lipsum import SURNAMES, MALE_NAMES, FEMALE_NAMES


def filesize(file):
    if isinstance(file, io.IOBase):
        return os.fstat(file.fileno()).st_size
    else:
        return os.stat(file).st_size


def random_person_entity_data(num):
    identities = []
    for i in range(num):
        gender = random.choices(
            ['man', 'woman', 'undefined'], cum_weights=[49, 49, 2])[0]
        if gender == 'man':
            names = random.choices(MALE_NAMES, k=random.randrange(2, 5))
        elif gender == 'woman':
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
            'gender': gender,
            'born': born
        })

    return identities
